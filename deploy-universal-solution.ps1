# Universal Manager Reports Solution - Automated Deployment Script
# This script automates the complete setup for any Microsoft 365 organization

param(
    [Parameter(Mandatory = $true)]
    [string]$OrganizationName,
    
    [Parameter(Mandatory = $false)]
    [string]$AdminEmail = "",
    
    [Parameter(Mandatory = $false)]
    [string]$ITSupportEmail = "",
    
    [Parameter(Mandatory = $false)]
    [string]$HREmail = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipAzureSetup = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestMode = $false
)

# Color output functions
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    else {
        $input | Write-Output
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Success($message) { Write-ColorOutput Green "✅ $message" }
function Write-Info($message) { Write-ColorOutput Cyan "ℹ️  $message" }
function Write-Warning($message) { Write-ColorOutput Yellow "⚠️  $message" }
function Write-Error($message) { Write-ColorOutput Red "❌ $message" }

# Banner
Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                    UNIVERSAL MANAGER REPORTS SOLUTION                       ║
║                         Automated Deployment Script                         ║
║                                                                              ║
║  This script will set up a complete manager reports solution for:           ║
║  Organization: $OrganizationName                                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝
"@

Write-Info "Starting deployment process..."

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsRole] "Administrator")) {
    Write-Warning "This script should be run as Administrator for best results."
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        exit 1
    }
}

# Phase 1: Install Required Modules
Write-Info "Phase 1: Installing Required PowerShell Modules"

$modules = @(
    'AzureAD',
    'Microsoft.PowerApps.Administration.PowerShell',
    'Microsoft.PowerApps.PowerShell',
    'ImportExcel'
)

foreach ($module in $modules) {
    try {
        Write-Info "Installing module: $module"
        if (!(Get-Module -ListAvailable -Name $module)) {
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
            Write-Success "Installed $module"
        } else {
            Write-Success "$module already installed"
        }
        Import-Module $module -Force
    }
    catch {
        Write-Error "Failed to install $module : $_"
        exit 1
    }
}

# Phase 2: Connect to Services
Write-Info "Phase 2: Connecting to Microsoft Services"

# Connect to Azure AD
try {
    Write-Info "Connecting to Azure AD..."
    Connect-AzureAD
    $tenantInfo = Get-AzureADTenantDetail
    Write-Success "Connected to Azure AD - Tenant: $($tenantInfo.DisplayName)"
}
catch {
    Write-Error "Failed to connect to Azure AD: $_"
    exit 1
}

# Connect to Power Platform
try {
    Write-Info "Connecting to Power Platform..."
    Add-PowerAppsAccount
    Write-Success "Connected to Power Platform"
}
catch {
    Write-Error "Failed to connect to Power Platform: $_"
    exit 1
}

# Phase 3: Gather Organization Information
Write-Info "Phase 3: Gathering Organization Information"

$orgInfo = @{
    Name = $OrganizationName
    TenantId = $tenantInfo.ObjectId
    Domain = $tenantInfo.VerifiedDomains | Where-Object { $_.Initial -eq $true } | Select-Object -ExpandProperty Name
    PrimaryDomain = $tenantInfo.VerifiedDomains | Where-Object { $_.Default -eq $true } | Select-Object -ExpandProperty Name
}

Write-Info "Organization Details:"
Write-Host "  Name: $($orgInfo.Name)"
Write-Host "  Tenant ID: $($orgInfo.TenantId)"
Write-Host "  Primary Domain: $($orgInfo.PrimaryDomain)"

# Get admin email if not provided
if ([string]::IsNullOrEmpty($AdminEmail)) {
    $currentUser = Get-AzureADCurrentSessionInfo
    $AdminEmail = $currentUser.Account.Id
    Write-Info "Using current user as admin: $AdminEmail"
}

# Set default emails if not provided
if ([string]::IsNullOrEmpty($ITSupportEmail)) {
    $ITSupportEmail = "support@$($orgInfo.PrimaryDomain)"
}
if ([string]::IsNullOrEmpty($HREmail)) {
    $HREmail = "hr@$($orgInfo.PrimaryDomain)"
}

$orgInfo.AdminEmail = $AdminEmail
$orgInfo.ITSupportEmail = $ITSupportEmail
$orgInfo.HREmail = $HREmail

# Phase 4: Azure AD App Registration
if (!$SkipAzureSetup) {
    Write-Info "Phase 4: Creating Azure AD App Registration"
    
    $appName = "Manager-Reports-$OrganizationName-$(Get-Date -Format 'yyyyMMdd')"
    $appUri = "https://manager-reports-$($OrganizationName.ToLower().Replace(' ', '-'))"
    
    try {
        # Create the application
        Write-Info "Creating Azure AD Application: $appName"
        $app = New-AzureADApplication -DisplayName $appName -IdentifierUris $appUri
        Write-Success "Application created with ID: $($app.AppId)"
        
        # Create service principal
        $sp = New-AzureADServicePrincipal -AppId $app.AppId
        Write-Success "Service Principal created"
        
        # Configure API permissions
        Write-Info "Configuring Microsoft Graph API permissions..."
        
        $requiredResourceAccess = @(
            @{
                ResourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
                ResourceAccess = @(
                    @{
                        Id = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
                        Type = "Role"
                    },
                    @{
                        Id = "7ab1d382-f21e-4acd-a863-ba3e13f7da61" # Directory.Read.All
                        Type = "Role"
                    },
                    @{
                        Id = "b633e1c5-b582-4048-a93e-9f11b44c7e96" # Mail.Send
                        Type = "Role"
                    }
                )
            }
        )
        
        Set-AzureADApplication -ObjectId $app.ObjectId -RequiredResourceAccess $requiredResourceAccess
        Write-Success "API permissions configured"
        
        # Create client secret
        Write-Info "Creating client secret..."
        $passwordCred = New-AzureADApplicationPasswordCredential -ObjectId $app.ObjectId -CustomKeyIdentifier "ManagerReportsSecret" -EndDate (Get-Date).AddMonths(24)
        Write-Success "Client secret created"
        
        # Grant admin consent
        Write-Info "Granting admin consent for permissions..."
        $graphSP = Get-AzureADServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"
        
        foreach ($permission in $requiredResourceAccess[0].ResourceAccess) {
            try {
                New-AzureADServiceAppRoleAssignment -ObjectId $sp.ObjectId -PrincipalId $sp.ObjectId -ResourceId $graphSP.ObjectId -Id $permission.Id
            }
            catch {
                Write-Warning "Could not grant permission $($permission.Id) - may need manual admin consent"
            }
        }
        Write-Success "Admin consent process completed"
        
        $orgInfo.ClientId = $app.AppId
        $orgInfo.ClientSecret = $passwordCred.Value
        $orgInfo.ApplicationName = $appName
        
    }
    catch {
        Write-Error "Failed to create Azure AD application: $_"
        exit 1
    }
} else {
    Write-Warning "Skipping Azure AD setup - you'll need to manually configure the app registration"
    $orgInfo.ClientId = "REPLACE_WITH_YOUR_CLIENT_ID"
    $orgInfo.ClientSecret = "REPLACE_WITH_YOUR_CLIENT_SECRET"
}

# Phase 5: Create Configuration Files
Write-Info "Phase 5: Creating Configuration Files"

$configDir = ".\ManagerReports-$OrganizationName-Config"
if (!(Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force
}

# Create main configuration file
$config = @{
    OrganizationInfo = $orgInfo
    DeploymentDate = Get-Date
    Version = "2.0"
    ConfiguredBy = $AdminEmail
}

$configJson = $config | ConvertTo-Json -Depth 10
$configJson | Out-File "$configDir\organization-config.json" -Encoding UTF8
Write-Success "Configuration saved to $configDir\organization-config.json"

# Update flow template with organization values
Write-Info "Customizing Power Automate flow template..."
$flowTemplate = Get-Content ".\universal-flow-template.json" -Raw
$flowTemplate = $flowTemplate.Replace("REPLACE_WITH_YOUR_TENANT_ID", $orgInfo.TenantId)
$flowTemplate = $flowTemplate.Replace("REPLACE_WITH_YOUR_CLIENT_ID", $orgInfo.ClientId)
$flowTemplate = $flowTemplate.Replace("REPLACE_WITH_YOUR_CLIENT_SECRET", $orgInfo.ClientSecret)

$flowTemplate | Out-File "$configDir\customized-flow-template.json" -Encoding UTF8
Write-Success "Customized flow template created"

# Create PowerShell configuration script
$psConfig = @"
# Configuration for $OrganizationName Manager Reports Solution
# Generated on: $(Get-Date)

`$OrganizationConfig = @{
    Name = "$($orgInfo.Name)"
    TenantId = "$($orgInfo.TenantId)"
    ClientId = "$($orgInfo.ClientId)"
    ClientSecret = "$($orgInfo.ClientSecret)"
    PrimaryDomain = "$($orgInfo.PrimaryDomain)"
    AdminEmail = "$($orgInfo.AdminEmail)"
    ITSupportEmail = "$($orgInfo.ITSupportEmail)"
    HREmail = "$($orgInfo.HREmail)"
}

# Test Microsoft Graph connectivity
function Test-GraphConnection {
    try {
        `$body = "client_id=`$(`$OrganizationConfig.ClientId)&client_secret=`$(`$OrganizationConfig.ClientSecret)&scope=https://graph.microsoft.com/.default&grant_type=client_credentials"
        `$response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/`$(`$OrganizationConfig.TenantId)/oauth2/v2.0/token" -Method POST -Body `$body -ContentType "application/x-www-form-urlencoded"
        Write-Host "✅ Graph API connection successful" -ForegroundColor Green
        return `$true
    }
    catch {
        Write-Host "❌ Graph API connection failed: `$_" -ForegroundColor Red
        return `$false
    }
}

# Export configuration
Export-ModuleMember -Variable OrganizationConfig -Function Test-GraphConnection
"@

$psConfig | Out-File "$configDir\Config.psm1" -Encoding UTF8
Write-Success "PowerShell configuration module created"

# Phase 6: Create Documentation
Write-Info "Phase 6: Creating Organization-Specific Documentation"

$userGuide = @"
# $OrganizationName Manager Reports - User Guide

## Quick Start
1. Go to [Power Automate](https://flow.microsoft.com)
2. Find the flow: "Universal Manager Reports"
3. Click "Run flow"
4. Enter a manager's email address
5. Select output format (Email or Excel)
6. Click "Run flow"

## Support Contacts
- **IT Support**: $($orgInfo.ITSupportEmail)
- **HR Contact**: $($orgInfo.HREmail)
- **System Administrator**: $($orgInfo.AdminEmail)

## Flow Information
- **Flow Name**: Universal Manager Reports
- **Deployment Date**: $(Get-Date -Format 'yyyy-MM-dd')
- **Version**: 2.0
- **Configured For**: $($orgInfo.Name)

## Features
- Get direct reports (immediate subordinates)
- Get indirect reports (up to 3 levels deep)
- Beautiful HTML email reports
- Excel/CSV export option
- Real-time data from Azure AD

## Data Sources
- **Employee Data**: Azure Active Directory
- **Organizational Structure**: Manager relationships in Azure AD
- **Contact Information**: Azure AD profiles

## Privacy and Compliance
- All employee data is handled according to $OrganizationName data governance policies
- Reports are generated in real-time and not stored
- Access is logged and auditable
- Complies with applicable privacy regulations

## Troubleshooting
### Common Issues:
1. **No reports found**: Verify manager has direct reports in Azure AD
2. **Permission errors**: Contact IT support for access review
3. **Email not received**: Check spam folder, verify email address
4. **Flow not found**: Ensure you have access to the Power Platform environment

### Getting Help:
- Level 1 Support: $($orgInfo.ITSupportEmail) (Response: 4 hours)
- Level 2 Support: $($orgInfo.AdminEmail) (Response: 2 hours)
- Emergency: Contact your IT helpdesk

Generated on: $(Get-Date)
"@

$userGuide | Out-File "$configDir\$OrganizationName-User-Guide.md" -Encoding UTF8
Write-Success "User guide created"

# Phase 7: Testing Configuration
if (!$TestMode) {
    Write-Info "Phase 7: Testing Configuration"
    
    # Test Azure AD connectivity
    try {
        $testUser = Get-AzureADUser -Top 1
        Write-Success "Azure AD connectivity verified"
    }
    catch {
        Write-Warning "Could not verify Azure AD connectivity: $_"
    }
    
    # Test Graph API authentication
    if (!$SkipAzureSetup) {
        try {
            $body = "client_id=$($orgInfo.ClientId)&client_secret=$($orgInfo.ClientSecret)&scope=https://graph.microsoft.com/.default&grant_type=client_credentials"
            $response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$($orgInfo.TenantId)/oauth2/v2.0/token" -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
            Write-Success "Microsoft Graph API authentication successful"
        }
        catch {
            Write-Warning "Microsoft Graph API authentication test failed: $_"
        }
    }
    
    # Get sample organizational data
    try {
        $userCount = (Get-AzureADUser -All $true | Measure-Object).Count
        $managerCount = (Get-AzureADUser -All $true | Where-Object { $_.JobTitle -like "*manager*" -or $_.JobTitle -like "*director*" -or $_.JobTitle -like "*lead*" } | Measure-Object).Count
        
        Write-Info "Organization Statistics:"
        Write-Host "  Total Users: $userCount"
        Write-Host "  Potential Managers: $managerCount"
    }
    catch {
        Write-Warning "Could not retrieve organizational statistics"
    }
}

# Phase 8: Generate Deployment Report
Write-Info "Phase 8: Generating Deployment Report"

$deploymentReport = @{
    Organization = $orgInfo.Name
    DeploymentDate = Get-Date
    DeployedBy = $AdminEmail
    TenantId = $orgInfo.TenantId
    ApplicationId = $orgInfo.ClientId
    ApplicationName = $orgInfo.ApplicationName
    ConfigurationFiles = @(
        "$configDir\organization-config.json",
        "$configDir\customized-flow-template.json",
        "$configDir\Config.psm1",
        "$configDir\$OrganizationName-User-Guide.md"
    )
    NextSteps = @(
        "Import the customized flow template into Power Automate",
        "Test the flow with a sample manager email",
        "Train end users using the provided user guide",
        "Set up monitoring and maintenance schedule",
        "Review and update permissions quarterly"
    )
    ImportantNotes = @(
        "Client secret expires in 24 months - set calendar reminder",
        "Admin consent may be required in Azure AD portal",
        "Flow requires Power Automate Premium licenses for HTTP connectors",
        "Test with small group before organization-wide rollout"
    )
}

$reportJson = $deploymentReport | ConvertTo-Json -Depth 10
$reportJson | Out-File "$configDir\deployment-report.json" -Encoding UTF8

# Create human-readable report
$readableReport = @"
# Deployment Report: $OrganizationName Manager Reports Solution

## Deployment Summary
- **Organization**: $($orgInfo.Name)
- **Deployment Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Deployed By**: $AdminEmail
- **Tenant ID**: $($orgInfo.TenantId)
- **Application ID**: $($orgInfo.ClientId)
- **Configuration Directory**: $configDir

## Azure AD Application Details
- **Application Name**: $($orgInfo.ApplicationName)
- **Client ID**: $($orgInfo.ClientId)
- **Client Secret**: Created (expires in 24 months)
- **Permissions**: User.Read.All, Directory.Read.All, Mail.Send

## Files Created
$($deploymentReport.ConfigurationFiles | ForEach-Object { "- $_" } | Out-String)

## Next Steps
$($deploymentReport.NextSteps | ForEach-Object { "$((1..20 | Measure-Object).Count). $_" } | Out-String)

## Important Notes
$($deploymentReport.ImportantNotes | ForEach-Object { "⚠️  $_" } | Out-String)

## Support Information
- **IT Support**: $($orgInfo.ITSupportEmail)
- **HR Contact**: $($orgInfo.HREmail)
- **Administrator**: $($orgInfo.AdminEmail)

## Security Reminders
- Store client secret securely
- Review permissions quarterly
- Monitor flow usage and errors
- Update documentation as needed

Generated by Universal Manager Reports Deployment Script v2.0
"@

$readableReport | Out-File "$configDir\deployment-report.md" -Encoding UTF8
Write-Success "Deployment report created"

# Phase 9: Final Summary
Write-Success "✅ DEPLOYMENT COMPLETE!"

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                            DEPLOYMENT COMPLETE                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

📁 Configuration files created in: $configDir

📋 Next Steps:
   1. Review the deployment report: $configDir\deployment-report.md
   2. Import flow template: $configDir\customized-flow-template.json
   3. Test with your email address
   4. Distribute user guide: $configDir\$OrganizationName-User-Guide.md

🔐 Security Information:
   • Client Secret: $(if($SkipAzureSetup){"Manual setup required"}else{"Created (save securely!)"})
   • Application ID: $($orgInfo.ClientId)
   • Tenant ID: $($orgInfo.TenantId)

📞 Support Contacts:
   • IT Support: $($orgInfo.ITSupportEmail)
   • Administrator: $($orgInfo.AdminEmail)

⚠️  Important: 
   • Client secret expires in 24 months
   • Test thoroughly before organization-wide deployment
   • Review Azure AD admin consent requirements

"@

# Optional: Open configuration directory
$openDir = Read-Host "Open configuration directory now? (y/N)"
if ($openDir -eq 'y' -or $openDir -eq 'Y') {
    Invoke-Item $configDir
}

Write-Success "Deployment script completed successfully!"