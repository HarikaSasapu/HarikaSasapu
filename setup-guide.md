# Setup Guide: Manager Reports Power Automate Flow

## Prerequisites Checklist

### 1. Microsoft 365 Requirements
- [ ] Microsoft 365 tenant with administrative access
- [ ] Power Automate Premium license (required for HTTP connectors)
- [ ] Azure Active Directory (AAD) with user management
- [ ] Office 365 account with email capabilities

### 2. Permissions Required
- [ ] **Azure AD Permissions**:
  - `User.Read.All` - Read all user profiles
  - `Directory.Read.All` - Read directory data
  - `Mail.Send` - Send emails on behalf of users

### 3. Technical Prerequisites
- [ ] Access to Azure Portal for app registration
- [ ] Power Automate designer access
- [ ] Basic understanding of Microsoft Graph API

## Step 1: Azure App Registration

### 1.1 Create App Registration
1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** > **App registrations**
3. Click **New registration**
4. Fill in the details:
   ```
   Name: Manager Reports Flow
   Supported account types: Accounts in this organizational directory only
   Redirect URI: (Leave blank)
   ```
5. Click **Register**

### 1.2 Configure API Permissions
1. In your app registration, go to **API permissions**
2. Click **Add a permission**
3. Select **Microsoft Graph** > **Application permissions**
4. Add the following permissions:
   - `User.Read.All`
   - `Directory.Read.All`
   - `Mail.Send`
5. Click **Grant admin consent** for your organization

### 1.3 Create Client Secret
1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Add description: "Manager Reports Flow Secret"
4. Set expiration: 24 months (recommended)
5. Click **Add**
6. **IMPORTANT**: Copy the secret value immediately (you won't see it again)

### 1.4 Note Important Values
Save these values for later configuration:
```
Tenant ID: [Your-Tenant-ID]
Client ID: [Your-Client-ID]  
Client Secret: [Your-Client-Secret]
```

## Step 2: Import Power Automate Flow

### 2.1 Import the Flow
1. Go to [Power Automate](https://flow.microsoft.com)
2. Click **My flows** > **Import** > **Import Package (Legacy)**
3. Upload the `manager-reports-flow-definition.json` file
4. Configure import settings:
   - Select **Create as new** for the flow
   - Set up Office 365 connection

### 2.2 Alternative: Manual Creation
If importing doesn't work, create manually:
1. Go to **My flows** > **New flow** > **Instant cloud flow**
2. Name: "Get Manager Reports"
3. Trigger: **PowerApps** or **Manually trigger a flow**
4. Follow the step-by-step actions from the documentation

## Step 3: Configure Flow Parameters

### 3.1 Add Environment Variables
1. In your flow, go to **Settings** > **Environment variables**
2. Create the following variables:
   ```
   Name: tenantId
   Type: Text
   Value: [Your-Tenant-ID]
   
   Name: clientId  
   Type: Text
   Value: [Your-Client-ID]
   
   Name: clientSecret
   Type: Text
   Value: [Your-Client-Secret]
   ```

### 3.2 Alternative: Direct Configuration
If environment variables aren't available, update the flow directly:
1. Find the **Get_Access_Token** action
2. Replace parameters in the URI and body:
   ```
   URI: https://login.microsoftonline.com/[YOUR-TENANT-ID]/oauth2/v2.0/token
   Body: client_id=[YOUR-CLIENT-ID]&client_secret=[YOUR-CLIENT-SECRET]&scope=https://graph.microsoft.com/.default&grant_type=client_credentials
   ```

## Step 4: Set Up Connections

### 4.1 Office 365 Connection
1. In the flow designer, find actions using Office 365
2. Click **Add new connection**
3. Sign in with an account that has permission to send emails
4. Authorize the connection

### 4.2 Test Connection
1. Save the flow
2. Test with a sample manager email
3. Verify that authentication works

## Step 5: Testing and Validation

### 5.1 Test Flow
1. Click **Test** in the flow designer
2. Select **Manually**
3. Enter a manager's email address
4. Run the test
5. Check for successful execution

### 5.2 Validate Output
Verify the following:
- [ ] Manager information retrieved correctly
- [ ] Direct reports listed
- [ ] Indirect reports included (if any)
- [ ] Email sent successfully
- [ ] Data formatted properly

### 5.3 Sample Test Data
Use these test scenarios:
```
Test 1: Manager with direct reports only
Email: manager1@company.com

Test 2: Manager with indirect reports  
Email: senior-manager@company.com

Test 3: Employee with no reports
Email: individual-contributor@company.com
```

## Step 6: Production Deployment

### 6.1 Create Scheduled Flow (Optional)
1. Create a copy of the flow
2. Change trigger to **Recurrence**
3. Set schedule (daily/weekly/monthly)
4. Add list of managers to process
5. Configure batch processing

### 6.2 Error Handling Setup
1. Add error handling scopes
2. Configure failure notifications
3. Set up retry logic
4. Add logging for troubleshooting

### 6.3 Security Review
- [ ] Review app permissions
- [ ] Validate data access patterns  
- [ ] Confirm email distribution
- [ ] Check audit trail capabilities

## Step 7: Power App Integration (Optional)

### 7.1 Create Power App
1. Go to [Power Apps](https://powerapps.microsoft.com)
2. Create new canvas app
3. Add text input for manager email
4. Add button to trigger flow
5. Display results in gallery

### 7.2 Sample Power App Formula
```powerapps
// Button OnSelect property
Set(
    FlowResult,
    'Get Manager Reports'.Run(TextInput1.Text)
);
Set(ReportsVisible, true)

// Gallery Items property  
FlowResult.reportData
```

## Step 8: SharePoint Integration (Optional)

### 8.1 Create SharePoint List
1. Go to SharePoint site
2. Create new list: "Manager Reports"
3. Add columns:
   - Manager Name (Single line text)
   - Total Reports (Number)
   - Report Date (Date)
   - Report Data (Multiple lines text)

### 8.2 Update Flow for SharePoint
1. Add SharePoint connector
2. Replace/add SharePoint actions
3. Configure list item creation
4. Test SharePoint integration

## Troubleshooting Guide

### Common Issues and Solutions

#### Authentication Errors
**Error**: "Unauthorized" or "Access Denied"
**Solution**: 
- Verify app permissions in Azure AD
- Check admin consent is granted
- Validate client secret hasn't expired

#### Missing Data
**Error**: Some employees not showing up
**Solution**:
- Verify users exist in Azure AD
- Check reporting relationships are set
- Validate Graph API permissions

#### Performance Issues  
**Error**: Flow timeout or slow execution
**Solution**:
- Add pagination for large organizations
- Implement parallel processing
- Add delays between API calls

#### Email Delivery Issues
**Error**: Emails not being sent
**Solution**:
- Check Office 365 connection
- Verify sender permissions
- Review email format and recipients

### Debug Steps
1. **Check Flow History**: Review run history for errors
2. **Test API Calls**: Use Graph Explorer to test endpoints
3. **Validate Permissions**: Review Azure AD audit logs
4. **Monitor Usage**: Check API rate limits and quotas

## Maintenance and Updates

### Regular Tasks
- [ ] **Monthly**: Review app permissions and security
- [ ] **Quarterly**: Update client secrets before expiration  
- [ ] **Annually**: Review flow performance and optimization

### Monitoring Setup
1. Set up flow analytics
2. Configure failure notifications
3. Monitor API usage quotas
4. Track user adoption and feedback

## Support and Documentation

### Resources
- [Microsoft Graph API Documentation](https://docs.microsoft.com/en-us/graph/)
- [Power Automate Documentation](https://docs.microsoft.com/en-us/power-automate/)
- [Azure AD App Registration Guide](https://docs.microsoft.com/en-us/azure/active-directory/develop/)

### Getting Help
1. Check Microsoft 365 Message Center for service updates
2. Use Power Platform Community forums
3. Contact your organization's IT support
4. Open Microsoft support ticket for critical issues

## Security Best Practices

### Data Protection
- [ ] Use least privilege access principles
- [ ] Regular review of permissions and access
- [ ] Implement data retention policies
- [ ] Monitor for unusual access patterns

### Compliance Considerations
- [ ] GDPR compliance for employee data
- [ ] Data residency requirements
- [ ] Audit trail maintenance
- [ ] Privacy impact assessments

This setup guide provides comprehensive instructions for implementing the Manager Reports Power Automate flow. Follow each step carefully and test thoroughly before production deployment.