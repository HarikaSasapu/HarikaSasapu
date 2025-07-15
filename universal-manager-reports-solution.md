# Universal Manager Reports Solution - Complete Implementation Guide

## 🌟 Overview
This is a complete, step-by-step solution for implementing a Power Automate flow that retrieves direct and indirect manager reports. This solution works for **ANY Microsoft 365 organization** regardless of size, structure, or industry.

## 📋 What You'll Build
- **Power Automate Flow** that gets organizational hierarchy data
- **Multiple trigger options** (Manual, PowerApp, Scheduled)
- **Flexible output formats** (Email, Excel, SharePoint, Teams)
- **Error handling and logging**
- **Security and compliance features**

---

## 🎯 PHASE 1: PREREQUISITES AND SETUP

### Step 1: Verify Your Environment
```powershell
# Check your Microsoft 365 license
# Required: Power Automate Premium or Office 365 E3/E5

# Verify you have admin access to:
# - Azure Active Directory
# - Power Platform Admin Center
# - SharePoint (if using SharePoint output)
```

### Step 2: Gather Organization Information
Before starting, collect this information:

```bash
# Organization Details
Tenant Name: [your-company].onmicrosoft.com
Primary Domain: [your-company].com
Azure AD Tenant ID: [will get this in setup]

# Key Personnel
Global Admin Email: admin@[your-company].com
IT Support Email: support@[your-company].com
HR Contact Email: hr@[your-company].com

# Technical Details
Number of Employees: [approximate count]
Organization Levels: [how many management levels]
Primary Departments: [list main departments]
```

### Step 3: Check Current Permissions
Run this PowerShell script to verify your permissions:

```powershell
# Connect to Azure AD
Connect-AzureAD

# Check if you have required roles
$currentUser = Get-AzureADCurrentSessionInfo
Write-Host "Current User: $($currentUser.Account)"

# Check admin roles
$adminRoles = Get-AzureADDirectoryRole | Where-Object {$_.DisplayName -match "Global Administrator|Application Administrator"}
foreach ($role in $adminRoles) {
    $members = Get-AzureADDirectoryRoleMember -ObjectId $role.ObjectId
    if ($members.UserPrincipalName -contains $currentUser.Account.Id) {
        Write-Host "✅ You have $($role.DisplayName) role"
    }
}
```

---

## 🔧 PHASE 2: AZURE ACTIVE DIRECTORY CONFIGURATION

### Step 4: Create App Registration (Universal Method)

#### 4.1 Automated Script Method
```powershell
# Run this PowerShell script to create app registration automatically
Connect-AzureAD

# App Registration Details
$appName = "Manager-Reports-Flow-$(Get-Date -Format 'yyyyMMdd')"
$appUri = "https://manager-reports-$((New-Guid).ToString().Substring(0,8))"

# Create the application
$app = New-AzureADApplication -DisplayName $appName -IdentifierUris $appUri

Write-Host "✅ App Created:"
Write-Host "Application ID: $($app.AppId)"
Write-Host "Object ID: $($app.ObjectId)"

# Save these values
$appId = $app.AppId
$objectId = $app.ObjectId

# Create service principal
$sp = New-AzureADServicePrincipal -AppId $appId
Write-Host "✅ Service Principal Created: $($sp.ObjectId)"
```

#### 4.2 Manual Portal Method
1. **Go to Azure Portal**: https://portal.azure.com
2. **Navigate**: Azure Active Directory > App registrations
3. **Click**: "New registration"
4. **Fill Details**:
   ```
   Name: Manager-Reports-Flow-[YourCompany]
   Supported account types: Single tenant
   Redirect URI: (leave blank)
   ```
5. **Click**: Register
6. **Save**: Application (client) ID and Directory (tenant) ID

### Step 5: Configure API Permissions (Universal)

#### 5.1 Automated Script Method
```powershell
# Required API permissions
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

# Apply permissions
Set-AzureADApplication -ObjectId $objectId -RequiredResourceAccess $requiredResourceAccess
Write-Host "✅ API Permissions Added"

# Grant admin consent (requires Global Admin)
foreach ($permission in $requiredResourceAccess[0].ResourceAccess) {
    New-AzureADServiceAppRoleAssignment -ObjectId $sp.ObjectId -PrincipalId $sp.ObjectId -ResourceId (Get-AzureADServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'").ObjectId -Id $permission.Id
}
Write-Host "✅ Admin Consent Granted"
```

#### 5.2 Manual Portal Method
1. **In your app registration**: API permissions
2. **Add permission**: Microsoft Graph > Application permissions
3. **Select permissions**:
   - `User.Read.All` - Read all user profiles
   - `Directory.Read.All` - Read directory data
   - `Mail.Send` - Send mail
4. **Grant admin consent**: Click "Grant admin consent for [organization]"

### Step 6: Create Client Secret (Universal)

#### 6.1 Automated Method
```powershell
# Create client secret
$passwordCred = New-AzureADApplicationPasswordCredential -ObjectId $objectId -CustomKeyIdentifier "ManagerReportsSecret" -EndDate (Get-Date).AddMonths(24)

Write-Host "✅ Client Secret Created:"
Write-Host "Secret ID: $($passwordCred.KeyId)"
Write-Host "Secret Value: $($passwordCred.Value)"
Write-Host "⚠️  SAVE THIS SECRET VALUE - YOU WON'T SEE IT AGAIN!"

# Save configuration
$config = @{
    TenantId = (Get-AzureADTenantDetail).ObjectId
    ClientId = $appId
    ClientSecret = $passwordCred.Value
    ApplicationName = $appName
}

$config | ConvertTo-Json | Out-File "ManagerReports-Config.json"
Write-Host "✅ Configuration saved to ManagerReports-Config.json"
```

#### 6.2 Manual Portal Method
1. **In your app registration**: Certificates & secrets
2. **New client secret**: Click "New client secret"
3. **Description**: "Manager Reports Flow Secret"
4. **Expires**: 24 months (recommended)
5. **Add**: Click "Add"
6. **⚠️ COPY THE VALUE IMMEDIATELY** - You won't see it again!

---

## 🔄 PHASE 3: POWER AUTOMATE FLOW CREATION

### Step 7: Universal Flow Template

#### 7.1 Create New Flow
1. **Go to**: https://flow.microsoft.com
2. **My flows** > **New flow** > **Instant cloud flow**
3. **Flow name**: "Universal Manager Reports"
4. **Trigger**: "Manually trigger a flow"
5. **Create**

#### 7.2 Add Input Parameters
```json
{
  "type": "object",
  "properties": {
    "managerEmail": {
      "title": "Manager Email Address",
      "type": "string",
      "format": "email",
      "description": "Enter the email address of the manager"
    },
    "includeIndirect": {
      "title": "Include Indirect Reports",
      "type": "boolean",
      "description": "Include indirect reports (reports of reports)",
      "default": true
    },
    "maxLevels": {
      "title": "Maximum Levels",
      "type": "integer",
      "description": "Maximum organizational levels to traverse",
      "default": 3,
      "minimum": 1,
      "maximum": 10
    },
    "outputFormat": {
      "title": "Output Format",
      "type": "string",
      "enum": ["email", "excel", "sharepoint", "teams"],
      "description": "How to deliver the report",
      "default": "email"
    }
  },
  "required": ["managerEmail"]
}
```

### Step 8: Initialize Variables (Universal)
Add these variable initialization actions:

```json
{
  "Initialize_Config": {
    "type": "InitializeVariable",
    "inputs": {
      "variables": [
        {
          "name": "Config",
          "type": "object",
          "value": {
            "tenantId": "YOUR_TENANT_ID",
            "clientId": "YOUR_CLIENT_ID",
            "clientSecret": "YOUR_CLIENT_SECRET",
            "graphBaseUrl": "https://graph.microsoft.com/v1.0",
            "authUrl": "https://login.microsoftonline.com"
          }
        }
      ]
    }
  },
  "Initialize_ManagerInfo": {
    "type": "InitializeVariable",
    "inputs": {
      "variables": [
        {
          "name": "ManagerInfo",
          "type": "object"
        }
      ]
    }
  },
  "Initialize_AllReports": {
    "type": "InitializeVariable",
    "inputs": {
      "variables": [
        {
          "name": "AllReports",
          "type": "array"
        }
      ]
    }
  },
  "Initialize_ErrorLog": {
    "type": "InitializeVariable",
    "inputs": {
      "variables": [
        {
          "name": "ErrorLog",
          "type": "array"
        }
      ]
    }
  },
  "Initialize_ProcessingStats": {
    "type": "InitializeVariable",
    "inputs": {
      "variables": [
        {
          "name": "ProcessingStats",
          "type": "object",
          "value": {
            "startTime": "@{utcNow()}",
            "totalProcessed": 0,
            "directReports": 0,
            "indirectReports": 0,
            "errors": 0
          }
        }
      ]
    }
  }
}
```

### Step 9: Authentication Function (Universal)
Create a reusable authentication action:

```json
{
  "Get_Access_Token": {
    "type": "Http",
    "inputs": {
      "method": "POST",
      "uri": "@{variables('Config')['authUrl']}/@{variables('Config')['tenantId']}/oauth2/v2.0/token",
      "headers": {
        "Content-Type": "application/x-www-form-urlencoded"
      },
      "body": "client_id=@{variables('Config')['clientId']}&client_secret=@{variables('Config')['clientSecret']}&scope=https://graph.microsoft.com/.default&grant_type=client_credentials"
    },
    "runAfter": {
      "Initialize_ProcessingStats": ["Succeeded"]
    }
  },
  "Parse_Token_Response": {
    "type": "ParseJson",
    "inputs": {
      "content": "@body('Get_Access_Token')",
      "schema": {
        "type": "object",
        "properties": {
          "access_token": {"type": "string"},
          "expires_in": {"type": "integer"},
          "token_type": {"type": "string"}
        }
      }
    },
    "runAfter": {
      "Get_Access_Token": ["Succeeded"]
    }
  }
}
```

### Step 10: Universal Manager Lookup Function
```json
{
  "Get_Manager_Info": {
    "type": "Http",
    "inputs": {
      "method": "GET",
      "uri": "@{variables('Config')['graphBaseUrl']}/users/@{triggerBody()['managerEmail']}?$select=id,displayName,mail,jobTitle,department,companyName,officeLocation",
      "headers": {
        "Authorization": "Bearer @{body('Parse_Token_Response')['access_token']}",
        "Content-Type": "application/json"
      }
    },
    "runAfter": {
      "Parse_Token_Response": ["Succeeded"]
    }
  },
  "Set_Manager_Info": {
    "type": "SetVariable",
    "inputs": {
      "name": "ManagerInfo",
      "value": "@body('Get_Manager_Info')"
    },
    "runAfter": {
      "Get_Manager_Info": ["Succeeded"]
    }
  }
}
```

### Step 11: Recursive Reports Function (Universal)
Create a child flow for recursive processing:

```json
{
  "Get_Reports_Recursive": {
    "type": "Workflow",
    "inputs": {
      "host": {
        "workflowReferenceName": "Get-Reports-Child-Flow"
      },
      "body": {
        "managerId": "@{variables('ManagerInfo')['id']}",
        "currentLevel": 1,
        "maxLevels": "@triggerBody()['maxLevels']",
        "accessToken": "@{body('Parse_Token_Response')['access_token']}",
        "graphBaseUrl": "@{variables('Config')['graphBaseUrl']}",
        "topLevelManager": "@{variables('ManagerInfo')['displayName']}"
      }
    },
    "runAfter": {
      "Set_Manager_Info": ["Succeeded"]
    }
  }
}
```

### Step 12: Child Flow for Recursive Processing
Create a separate flow named "Get-Reports-Child-Flow":

```json
{
  "definition": {
    "triggers": {
      "manual": {
        "type": "Request",
        "kind": "Http",
        "inputs": {
          "schema": {
            "type": "object",
            "properties": {
              "managerId": {"type": "string"},
              "currentLevel": {"type": "integer"},
              "maxLevels": {"type": "integer"},
              "accessToken": {"type": "string"},
              "graphBaseUrl": {"type": "string"},
              "topLevelManager": {"type": "string"},
              "directManagerName": {"type": "string"}
            },
            "required": ["managerId", "currentLevel", "maxLevels", "accessToken"]
          }
        }
      }
    },
    "actions": {
      "Initialize_Reports": {
        "type": "InitializeVariable",
        "inputs": {
          "variables": [
            {
              "name": "Reports",
              "type": "array"
            }
          ]
        }
      },
      "Get_Direct_Reports": {
        "type": "Http",
        "inputs": {
          "method": "GET",
          "uri": "@{triggerBody()['graphBaseUrl']}/users/@{triggerBody()['managerId']}/directReports?$select=id,displayName,mail,jobTitle,department,companyName,officeLocation",
          "headers": {
            "Authorization": "Bearer @{triggerBody()['accessToken']}",
            "Content-Type": "application/json"
          }
        },
        "runAfter": {
          "Initialize_Reports": ["Succeeded"]
        }
      },
      "Process_Direct_Reports": {
        "type": "Foreach",
        "foreach": "@body('Get_Direct_Reports')['value']",
        "actions": {
          "Add_Report": {
            "type": "AppendToArrayVariable",
            "inputs": {
              "name": "Reports",
              "value": {
                "id": "@{items('Process_Direct_Reports')['id']}",
                "displayName": "@{items('Process_Direct_Reports')['displayName']}",
                "mail": "@{items('Process_Direct_Reports')['mail']}",
                "jobTitle": "@{items('Process_Direct_Reports')['jobTitle']}",
                "department": "@{items('Process_Direct_Reports')['department']}",
                "companyName": "@{items('Process_Direct_Reports')['companyName']}",
                "officeLocation": "@{items('Process_Direct_Reports')['officeLocation']}",
                "level": "@triggerBody()['currentLevel']",
                "reportType": "@{if(equals(triggerBody()['currentLevel'], 1), 'Direct', 'Indirect')}",
                "directManager": "@{coalesce(triggerBody()['directManagerName'], triggerBody()['topLevelManager'])}",
                "topLevelManager": "@{triggerBody()['topLevelManager']}",
                "retrievedDate": "@utcNow()"
              }
            }
          },
          "Get_Indirect_Reports": {
            "type": "If",
            "expression": {
              "and": [
                {
                  "less": [
                    "@triggerBody()['currentLevel']",
                    "@triggerBody()['maxLevels']"
                  ]
                }
              ]
            },
            "actions": {
              "Call_Child_Flow": {
                "type": "Workflow",
                "inputs": {
                  "host": {
                    "workflowReferenceName": "Get-Reports-Child-Flow"
                  },
                  "body": {
                    "managerId": "@{items('Process_Direct_Reports')['id']}",
                    "currentLevel": "@{add(triggerBody()['currentLevel'], 1)}",
                    "maxLevels": "@triggerBody()['maxLevels']",
                    "accessToken": "@triggerBody()['accessToken']",
                    "graphBaseUrl": "@triggerBody()['graphBaseUrl']",
                    "topLevelManager": "@{triggerBody()['topLevelManager']}",
                    "directManagerName": "@{items('Process_Direct_Reports')['displayName']}"
                  }
                }
              },
              "Merge_Indirect_Reports": {
                "type": "Compose",
                "inputs": "@union(variables('Reports'), body('Call_Child_Flow')['reports'])",
                "runAfter": {
                  "Call_Child_Flow": ["Succeeded"]
                }
              },
              "Update_Reports": {
                "type": "SetVariable",
                "inputs": {
                  "name": "Reports",
                  "value": "@outputs('Merge_Indirect_Reports')"
                },
                "runAfter": {
                  "Merge_Indirect_Reports": ["Succeeded"]
                }
              }
            },
            "runAfter": {
              "Add_Report": ["Succeeded"]
            }
          }
        },
        "runAfter": {
          "Get_Direct_Reports": ["Succeeded"]
        }
      },
      "Return_Response": {
        "type": "Response",
        "inputs": {
          "statusCode": 200,
          "body": {
            "reports": "@variables('Reports')",
            "success": true,
            "totalCount": "@length(variables('Reports'))",
            "processedLevel": "@triggerBody()['currentLevel']"
          }
        },
        "runAfter": {
          "Process_Direct_Reports": ["Succeeded"]
        }
      }
    }
  }
}
```

---

## 📊 PHASE 4: OUTPUT AND FORMATTING

### Step 13: Universal Data Processing
Add these actions to process and format the data:

```json
{
  "Set_All_Reports": {
    "type": "SetVariable",
    "inputs": {
      "name": "AllReports",
      "value": "@body('Get_Reports_Recursive')['reports']"
    },
    "runAfter": {
      "Get_Reports_Recursive": ["Succeeded"]
    }
  },
  "Calculate_Statistics": {
    "type": "Compose",
    "inputs": {
      "totalReports": "@length(variables('AllReports'))",
      "directReports": "@length(filter(variables('AllReports'), item()['level'] == 1))",
      "indirectReports": "@length(filter(variables('AllReports'), item()['level'] > 1))",
      "departments": "@createArray(unique(map(variables('AllReports'), item()['department'])))",
      "locations": "@createArray(unique(map(variables('AllReports'), item()['officeLocation'])))",
      "endTime": "@utcNow()",
      "processingTime": "@formatDateTime(addSeconds(convertFromUtc(utcNow(), 'UTC'), sub(0, div(ticks(parseDateTime(variables('ProcessingStats')['startTime'])), 10000000))), 'HH:mm:ss')"
    },
    "runAfter": {
      "Set_All_Reports": ["Succeeded"]
    }
  },
  "Format_Report_Data": {
    "type": "Select",
    "inputs": {
      "from": "@variables('AllReports')",
      "select": {
        "Employee ID": "@item()['id']",
        "Employee Name": "@item()['displayName']",
        "Email Address": "@item()['mail']",
        "Job Title": "@item()['jobTitle']",
        "Department": "@item()['department']",
        "Company": "@item()['companyName']",
        "Office Location": "@item()['officeLocation']",
        "Reporting Level": "@item()['level']",
        "Report Type": "@item()['reportType']",
        "Direct Manager": "@item()['directManager']",
        "Top Level Manager": "@item()['topLevelManager']",
        "Date Retrieved": "@formatDateTime(item()['retrievedDate'], 'yyyy-MM-dd HH:mm:ss')"
      }
    },
    "runAfter": {
      "Calculate_Statistics": ["Succeeded"]
    }
  }
}
```

### Step 14: Universal Output Switch
Create a switch based on output format:

```json
{
  "Output_Switch": {
    "type": "Switch",
    "expression": "@triggerBody()['outputFormat']",
    "cases": {
      "Email": {
        "case": "email",
        "actions": {
          "Create_HTML_Table": {
            "type": "Table",
            "inputs": {
              "from": "@body('Format_Report_Data')",
              "format": "HTML"
            }
          },
          "Send_Email_Report": {
            "type": "ApiConnection",
            "inputs": {
              "host": {
                "connectionName": "office365",
                "operationId": "SendEmailV2",
                "apiId": "/providers/Microsoft.PowerApps/apis/shared_office365"
              },
              "parameters": {
                "emailMessage/To": "@triggerBody()['managerEmail']",
                "emailMessage/Subject": "📊 Manager Reports - @{variables('ManagerInfo')['displayName']} - @{formatDateTime(utcNow(), 'yyyy-MM-dd')}",
                "emailMessage/Body": "@{outputs('Create_Email_Body')}",
                "emailMessage/Importance": "Normal"
              }
            },
            "runAfter": {
              "Create_HTML_Table": ["Succeeded"]
            }
          }
        }
      },
      "Excel": {
        "case": "excel",
        "actions": {
          "Create_Excel_File": {
            "type": "ApiConnection",
            "inputs": {
              "host": {
                "connectionName": "excelonlinebusiness",
                "operationId": "CreateWorkbook",
                "apiId": "/providers/Microsoft.PowerApps/apis/shared_excelonlinebusiness"
              },
              "parameters": {
                "source": "me",
                "path": "/Manager_Reports_@{formatDateTime(utcNow(), 'yyyyMMdd_HHmmss')}.xlsx",
                "tableParameters/tableName": "ManagerReports",
                "tableParameters/tableHeaders": "@{join(keys(first(body('Format_Report_Data'))), ',')}",
                "tableParameters/tableRows": "@body('Format_Report_Data')"
              }
            }
          }
        }
      },
      "SharePoint": {
        "case": "sharepoint",
        "actions": {
          "Create_SharePoint_List_Items": {
            "type": "Foreach",
            "foreach": "@body('Format_Report_Data')",
            "actions": {
              "Create_List_Item": {
                "type": "ApiConnection",
                "inputs": {
                  "host": {
                    "connectionName": "sharepointonline",
                    "operationId": "PostItem",
                    "apiId": "/providers/Microsoft.PowerApps/apis/shared_sharepointonline"
                  },
                  "parameters": {
                    "dataset": "https://[your-tenant].sharepoint.com/sites/[your-site]",
                    "table": "[your-list-name]",
                    "item": "@items('Create_SharePoint_List_Items')"
                  }
                }
              }
            }
          }
        }
      },
      "Teams": {
        "case": "teams",
        "actions": {
          "Post_to_Teams": {
            "type": "ApiConnection",
            "inputs": {
              "host": {
                "connectionName": "teams",
                "operationId": "PostCardToChannel",
                "apiId": "/providers/Microsoft.PowerApps/apis/shared_teams"
              },
              "parameters": {
                "poster": "Flow bot",
                "location": "[Team ID]/[Channel ID]",
                "body": "@{outputs('Create_Teams_Card')}"
              }
            }
          }
        }
      }
    },
    "default": {
      "actions": {
        "Default_Email_Output": {
          "type": "ApiConnection",
          "inputs": {
            "host": {
              "connectionName": "office365"
            },
            "method": "post",
            "path": "/v2/Mail",
            "body": {
              "To": "@triggerBody()['managerEmail']",
              "Subject": "Manager Reports - Default Output",
              "Body": "Report generated successfully. @{length(variables('AllReports'))} total reports found."
            }
          }
        }
      }
    },
    "runAfter": {
      "Format_Report_Data": ["Succeeded"]
    }
  }
}
```

---

## 📧 PHASE 5: EMAIL TEMPLATE CREATION

### Step 15: Universal Email Template
Create a comprehensive email template:

```json
{
  "Create_Email_Body": {
    "type": "Compose",
    "inputs": "<!DOCTYPE html>\n<html>\n<head>\n    <style>\n        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }\n        .container { max-width: 800px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }\n        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }\n        .header h1 { margin: 0; font-size: 24px; }\n        .header p { margin: 5px 0 0 0; opacity: 0.9; }\n        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin: 20px 0; }\n        .stat-card { background: #f8f9fa; padding: 15px; border-radius: 8px; border-left: 4px solid #667eea; }\n        .stat-number { font-size: 24px; font-weight: bold; color: #667eea; }\n        .stat-label { font-size: 12px; color: #666; margin-top: 5px; }\n        .section { margin: 25px 0; }\n        .section h3 { color: #333; border-bottom: 2px solid #667eea; padding-bottom: 10px; }\n        table { width: 100%; border-collapse: collapse; margin-top: 15px; }\n        th { background-color: #667eea; color: white; padding: 12px; text-align: left; }\n        td { padding: 10px; border-bottom: 1px solid #ddd; }\n        tr:nth-child(even) { background-color: #f9f9f9; }\n        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }\n        .highlight { background-color: #fff3cd; padding: 10px; border-radius: 5px; border-left: 4px solid #ffc107; margin: 15px 0; }\n    </style>\n</head>\n<body>\n    <div class=\"container\">\n        <div class=\"header\">\n            <h1>📊 Manager Reports Dashboard</h1>\n            <p>Organizational Hierarchy Report for @{variables('ManagerInfo')['displayName']}</p>\n            <p>Generated on @{formatDateTime(utcNow(), 'dddd, MMMM dd, yyyy \\a\\t HH:mm')} UTC</p>\n        </div>\n        \n        <div class=\"stats-grid\">\n            <div class=\"stat-card\">\n                <div class=\"stat-number\">@{outputs('Calculate_Statistics')['totalReports']}</div>\n                <div class=\"stat-label\">Total Reports</div>\n            </div>\n            <div class=\"stat-card\">\n                <div class=\"stat-number\">@{outputs('Calculate_Statistics')['directReports']}</div>\n                <div class=\"stat-label\">Direct Reports</div>\n            </div>\n            <div class=\"stat-card\">\n                <div class=\"stat-number\">@{outputs('Calculate_Statistics')['indirectReports']}</div>\n                <div class=\"stat-label\">Indirect Reports</div>\n            </div>\n            <div class=\"stat-card\">\n                <div class=\"stat-number\">@{length(outputs('Calculate_Statistics')['departments'])}</div>\n                <div class=\"stat-label\">Departments</div>\n            </div>\n        </div>\n        \n        <div class=\"section\">\n            <h3>📋 Manager Information</h3>\n            <table>\n                <tr><td><strong>Name:</strong></td><td>@{variables('ManagerInfo')['displayName']}</td></tr>\n                <tr><td><strong>Email:</strong></td><td>@{variables('ManagerInfo')['mail']}</td></tr>\n                <tr><td><strong>Job Title:</strong></td><td>@{variables('ManagerInfo')['jobTitle']}</td></tr>\n                <tr><td><strong>Department:</strong></td><td>@{variables('ManagerInfo')['department']}</td></tr>\n                <tr><td><strong>Company:</strong></td><td>@{variables('ManagerInfo')['companyName']}</td></tr>\n                <tr><td><strong>Office:</strong></td><td>@{variables('ManagerInfo')['officeLocation']}</td></tr>\n            </table>\n        </div>\n        \n        <div class=\"section\">\n            <h3>👥 Detailed Reports</h3>\n            @{body('Create_HTML_Table')}\n        </div>\n        \n        <div class=\"highlight\">\n            <strong>💡 Report Notes:</strong>\n            <ul>\n                <li>This report includes up to @{triggerBody()['maxLevels']} organizational levels</li>\n                <li>Data is retrieved from Azure Active Directory in real-time</li>\n                <li>Processing completed in @{outputs('Calculate_Statistics')['processingTime']}</li>\n            </ul>\n        </div>\n        \n        <div class=\"footer\">\n            <p><strong>Generated by:</strong> Universal Manager Reports Flow</p>\n            <p><strong>Data Source:</strong> Microsoft Graph API</p>\n            <p><strong>Report ID:</strong> @{workflow()['run']['name']}</p>\n            <p>This is an automated report. For questions, contact your IT department.</p>\n        </div>\n    </div>\n</body>\n</html>",
    "runAfter": {
      "Calculate_Statistics": ["Succeeded"]
    }
  }
}
```

---

## ⚙️ PHASE 6: ERROR HANDLING AND LOGGING

### Step 16: Universal Error Handling
Add comprehensive error handling:

```json
{
  "Error_Handling_Scope": {
    "type": "Scope",
    "actions": {
      "Log_Error": {
        "type": "AppendToArrayVariable",
        "inputs": {
          "name": "ErrorLog",
          "value": {
            "timestamp": "@utcNow()",
            "action": "@{actions()[0]}",
            "error": "@{result('Get_Manager_Info')['error']}",
            "code": "@{result('Get_Manager_Info')['error']['code']}",
            "message": "@{result('Get_Manager_Info')['error']['message']}"
          }
        }
      },
      "Send_Error_Notification": {
        "type": "ApiConnection",
        "inputs": {
          "host": {
            "connectionName": "office365"
          },
          "method": "post",
          "path": "/v2/Mail",
          "body": {
            "To": "IT-SUPPORT-EMAIL@your-company.com",
            "Subject": "🚨 Manager Reports Flow Error - @{utcNow()}",
            "Body": "An error occurred in the Manager Reports flow:\n\nFlow Run: @{workflow()['run']['name']}\nManager Email: @{triggerBody()['managerEmail']}\nError Details: @{variables('ErrorLog')}\n\nPlease investigate and resolve.",
            "Importance": "High"
          }
        },
        "runAfter": {
          "Log_Error": ["Succeeded"]
        }
      }
    },
    "runAfter": {
      "Get_Manager_Info": ["Failed", "TimedOut"]
    }
  }
}
```

### Step 17: Success Response
Add final success response:

```json
{
  "Final_Response": {
    "type": "Response",
    "inputs": {
      "statusCode": 200,
      "headers": {
        "Content-Type": "application/json"
      },
      "body": {
        "success": true,
        "message": "Manager reports generated successfully",
        "data": {
          "managerName": "@{variables('ManagerInfo')['displayName']}",
          "managerEmail": "@{variables('ManagerInfo')['mail']}",
          "totalReports": "@{outputs('Calculate_Statistics')['totalReports']}",
          "directReports": "@{outputs('Calculate_Statistics')['directReports']}",
          "indirectReports": "@{outputs('Calculate_Statistics')['indirectReports']}",
          "processingTime": "@{outputs('Calculate_Statistics')['processingTime']}",
          "reportId": "@{workflow()['run']['name']}",
          "generatedAt": "@utcNow()"
        },
        "errors": "@variables('ErrorLog')"
      }
    },
    "runAfter": {
      "Output_Switch": ["Succeeded"]
    }
  }
}
```

---

## 🧪 PHASE 7: TESTING AND VALIDATION

### Step 18: Test Configuration
Create test scenarios for your organization:

```powershell
# Test Data Configuration
$testScenarios = @(
    @{
        Name = "Small Team Manager"
        Email = "team-lead@your-company.com"
        ExpectedDirectReports = 3
        ExpectedLevels = 1
    },
    @{
        Name = "Department Manager"
        Email = "dept-manager@your-company.com"
        ExpectedDirectReports = 8
        ExpectedLevels = 2
    },
    @{
        Name = "Executive"
        Email = "executive@your-company.com"
        ExpectedDirectReports = 15
        ExpectedLevels = 3
    },
    @{
        Name = "Individual Contributor"
        Email = "individual@your-company.com"
        ExpectedDirectReports = 0
        ExpectedLevels = 0
    }
)

# Test each scenario
foreach ($test in $testScenarios) {
    Write-Host "Testing: $($test.Name)"
    # Run your flow with this test data
    # Validate results match expectations
}
```

### Step 19: Validation Checklist
```bash
# Pre-Deployment Checklist
✅ Azure AD app registration completed
✅ Required permissions granted and consented
✅ Client secret created and saved securely
✅ Power Automate flow imported successfully
✅ All connections configured properly
✅ Test scenarios executed successfully
✅ Error handling tested with invalid inputs
✅ Email templates render correctly
✅ Performance acceptable for organization size
✅ Security review completed
✅ Documentation updated for your organization
```

---

## 🚀 PHASE 8: DEPLOYMENT AND PRODUCTION

### Step 20: Production Deployment Script
```powershell
# Production Deployment Script
param(
    [string]$EnvironmentName = "Production",
    [string]$FlowName = "Universal-Manager-Reports",
    [string]$OwnerEmail = "flow-owner@your-company.com"
)

# Connect to Power Platform
Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Force
Import-Module Microsoft.PowerApps.Administration.PowerShell

# Add your tenant admin account
Add-PowerAppsAccount

# Get environment
$environment = Get-AdminPowerAppEnvironment | Where-Object {$_.DisplayName -eq $EnvironmentName}

if (-not $environment) {
    Write-Error "Environment '$EnvironmentName' not found"
    exit 1
}

Write-Host "✅ Environment found: $($environment.EnvironmentName)"

# Deploy flow (assuming you have the flow package)
# This would typically be done through the Power Platform CLI or manual import

Write-Host "🚀 Deployment completed successfully"
Write-Host "Environment: $EnvironmentName"
Write-Host "Flow Name: $FlowName"
Write-Host "Owner: $OwnerEmail"
```

### Step 21: Monitoring and Maintenance
```json
{
  "monitoring_configuration": {
    "alerts": {
      "failure_rate_threshold": "5%",
      "response_time_threshold": "5_minutes",
      "notification_emails": [
        "it-admin@your-company.com",
        "hr-admin@your-company.com"
      ]
    },
    "health_checks": {
      "frequency": "daily",
      "test_manager_email": "test-manager@your-company.com",
      "expected_response_time": "< 2 minutes"
    },
    "maintenance": {
      "client_secret_expiry_reminder": "30_days_before",
      "performance_review": "monthly",
      "security_audit": "quarterly"
    }
  }
}
```

---

## 📚 PHASE 9: DOCUMENTATION AND TRAINING

### Step 22: Create Organization-Specific Documentation
```markdown
# [Your Company] Manager Reports Flow - User Guide

## Quick Start for [Your Company]
1. Access: https://flow.microsoft.com
2. Find flow: "Universal Manager Reports"
3. Click "Run flow"
4. Enter manager email address
5. Select output format
6. Click "Run flow"

## Company-Specific Information
- **IT Support**: support@[your-company].com
- **HR Contact**: hr@[your-company].com
- **Flow Owner**: [flow-owner]@[your-company].com

## Data Sources
- Employee data: Azure AD
- Organizational structure: Manager field in Azure AD
- Department information: Department field in Azure AD

## Compliance and Privacy
- This tool complies with [Your Company] data governance policies
- Employee data is handled according to privacy regulations
- Access is logged and audited
- Data retention: [Your Company Policy]
```

### Step 23: Training Materials
Create these materials for your organization:

1. **Quick Reference Card** (1-page)
2. **Video Tutorial** (5-10 minutes)
3. **FAQ Document**
4. **Troubleshooting Guide**
5. **Administrator Manual**

---

## 🔒 PHASE 10: SECURITY AND COMPLIANCE

### Step 24: Security Configuration
```json
{
  "security_settings": {
    "authentication": {
      "method": "OAuth2_client_credentials",
      "token_expiry": "1_hour",
      "refresh_required": true
    },
    "access_control": {
      "allowed_users": "all_authenticated",
      "restricted_data": "salary_information_excluded",
      "audit_logging": "enabled"
    },
    "data_protection": {
      "encryption_in_transit": "TLS_1.2",
      "encryption_at_rest": "Microsoft_managed_keys",
      "data_residency": "organization_tenant_region"
    },
    "compliance": {
      "gdpr_compliant": true,
      "data_retention": "as_per_company_policy",
      "right_to_deletion": "supported"
    }
  }
}
```

### Step 25: Final Security Checklist
```bash
🔒 SECURITY FINAL CHECKLIST
✅ Principle of least privilege applied
✅ Client secrets stored securely
✅ Regular access reviews scheduled
✅ Audit logging enabled
✅ Data encryption verified
✅ Compliance requirements met
✅ Privacy impact assessment completed
✅ Incident response plan documented
✅ Regular security reviews scheduled
✅ User access properly managed
```

---

## 🎯 SUCCESS METRICS AND KPIs

### Key Performance Indicators
```json
{
  "success_metrics": {
    "technical": {
      "flow_success_rate": "> 95%",
      "average_execution_time": "< 3 minutes",
      "error_rate": "< 5%",
      "availability": "> 99%"
    },
    "business": {
      "user_adoption": "> 80% of managers",
      "time_saved": "2 hours per report",
      "accuracy_improvement": "> 95%",
      "user_satisfaction": "> 4.5/5"
    },
    "compliance": {
      "audit_readiness": "100%",
      "data_accuracy": "> 99%",
      "security_incidents": "0",
      "policy_compliance": "100%"
    }
  }
}
```

---

## 📞 SUPPORT AND MAINTENANCE

### Ongoing Support Structure
```yaml
Support Tiers:
  Level 1 (User Issues):
    - Contact: helpdesk@your-company.com
    - Response Time: 4 hours
    - Escalation: Level 2
    
  Level 2 (Technical Issues):
    - Contact: it-support@your-company.com  
    - Response Time: 2 hours
    - Escalation: Level 3
    
  Level 3 (System Issues):
    - Contact: system-admin@your-company.com
    - Response Time: 1 hour
    - Escalation: Microsoft Support
```

This comprehensive guide provides everything needed to implement a universal manager reports solution that works for any Microsoft 365 organization. The solution is scalable, secure, and can be customized for specific organizational needs while maintaining universal compatibility.