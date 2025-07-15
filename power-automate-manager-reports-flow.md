# Power Automate Flow: Get Direct and Indirect Manager Reports

## Overview
This Power Automate flow retrieves all direct and indirect reports for a specified manager using Microsoft Graph API. The flow can be triggered manually or scheduled to run automatically.

## Features
- **Direct Reports**: Gets immediate subordinates of a manager
- **Indirect Reports**: Recursively retrieves all reports down the hierarchy chain
- **Comprehensive Data**: Includes employee details like name, email, job title, department
- **Flexible Output**: Can export to Excel, SharePoint, or send via email
- **Error Handling**: Includes proper error handling and logging

## Prerequisites
- Microsoft 365 tenant with appropriate permissions
- Power Automate Premium license (for HTTP connectors)
- Microsoft Graph API permissions:
  - `User.Read.All`
  - `Directory.Read.All`

## Flow Architecture

### 1. Trigger
- **Type**: Manual trigger or Scheduled trigger
- **Input**: Manager's email address or User ID

### 2. Main Components
1. **Initialize Variables**
2. **Get Manager Information**
3. **Get Direct Reports**
4. **Recursive Function for Indirect Reports**
5. **Data Processing and Formatting**
6. **Output Generation**

## Detailed Flow Steps

### Step 1: Initialize Variables
```json
{
  "Initialize_DirectReports": {
    "type": "InitializeVariable",
    "inputs": {
      "variables": [
        {
          "name": "DirectReports",
          "type": "array"
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
  "Initialize_ManagerEmail": {
    "type": "InitializeVariable",
    "inputs": {
      "variables": [
        {
          "name": "ManagerEmail",
          "type": "string",
          "value": "@{triggerBody()['text']}"
        }
      ]
    }
  }
}
```

### Step 2: Get Manager Information
Use HTTP action to call Microsoft Graph API:

**HTTP Request Configuration:**
- **Method**: GET
- **URI**: `https://graph.microsoft.com/v1.0/users/@{variables('ManagerEmail')}`
- **Headers**: 
  ```json
  {
    "Authorization": "Bearer @{body('Get_Access_Token')?['access_token']}",
    "Content-Type": "application/json"
  }
  ```

### Step 3: Get Direct Reports
**HTTP Request Configuration:**
- **Method**: GET  
- **URI**: `https://graph.microsoft.com/v1.0/users/@{body('Get_Manager')?['id']}/directReports`
- **Headers**: Same as above

### Step 4: Process Direct Reports
Use **Apply to Each** action to iterate through direct reports:

```json
{
  "Apply_to_each_DirectReport": {
    "type": "Foreach",
    "inputs": {
      "foreach": "@body('Get_Direct_Reports')?['value']"
    },
    "actions": {
      "Append_to_DirectReports": {
        "type": "AppendToArrayVariable",
        "inputs": {
          "name": "DirectReports",
          "value": {
            "id": "@{items('Apply_to_each_DirectReport')?['id']}",
            "displayName": "@{items('Apply_to_each_DirectReport')?['displayName']}",
            "mail": "@{items('Apply_to_each_DirectReport')?['mail']}",
            "jobTitle": "@{items('Apply_to_each_DirectReport')?['jobTitle']}",
            "department": "@{items('Apply_to_each_DirectReport')?['department']}",
            "level": 1,
            "manager": "@{body('Get_Manager')?['displayName']}"
          }
        }
      }
    }
  }
}
```

### Step 5: Recursive Function for Indirect Reports
Create a child flow or use nested loops to get indirect reports:

```json
{
  "Get_Indirect_Reports": {
    "type": "Foreach",
    "inputs": {
      "foreach": "@variables('DirectReports')"
    },
    "actions": {
      "HTTP_Get_SubordinateReports": {
        "type": "Http",
        "inputs": {
          "method": "GET",
          "uri": "https://graph.microsoft.com/v1.0/users/@{items('Get_Indirect_Reports')?['id']}/directReports",
          "headers": {
            "Authorization": "Bearer @{body('Get_Access_Token')?['access_token']}"
          }
        }
      },
      "Process_SubordinateReports": {
        "type": "Foreach",
        "inputs": {
          "foreach": "@body('HTTP_Get_SubordinateReports')?['value']"
        },
        "actions": {
          "Append_IndirectReport": {
            "type": "AppendToArrayVariable",
            "inputs": {
              "name": "AllReports",
              "value": {
                "id": "@{items('Process_SubordinateReports')?['id']}",
                "displayName": "@{items('Process_SubordinateReports')?['displayName']}",
                "mail": "@{items('Process_SubordinateReports')?['mail']}",
                "jobTitle": "@{items('Process_SubordinateReports')?['jobTitle']}",
                "department": "@{items('Process_SubordinateReports')?['department']}",
                "level": 2,
                "directManager": "@{items('Get_Indirect_Reports')?['displayName']}",
                "topLevelManager": "@{body('Get_Manager')?['displayName']}"
              }
            }
          }
        }
      }
    }
  }
}
```

### Step 6: Combine and Format Data
```json
{
  "Union_AllReports": {
    "type": "Compose",
    "inputs": "@union(variables('DirectReports'), variables('AllReports'))"
  },
  "Format_ReportData": {
    "type": "Select",
    "inputs": {
      "from": "@outputs('Union_AllReports')",
      "select": {
        "Employee Name": "@item()?['displayName']",
        "Email": "@item()?['mail']",
        "Job Title": "@item()?['jobTitle']",
        "Department": "@item()?['department']",
        "Reporting Level": "@item()?['level']",
        "Direct Manager": "@item()?['directManager']",
        "Top Level Manager": "@item()?['topLevelManager']",
        "Date Generated": "@utcNow()"
      }
    }
  }
}
```

### Step 7: Output Options

#### Option A: Create Excel File
```json
{
  "Create_Excel_Table": {
    "type": "ApiConnection",
    "inputs": {
      "host": {
        "connectionName": "excelonlinebusiness"
      },
      "method": "post",
      "path": "/drives/@{encodeURIComponent('b!...')}/items/@{encodeURIComponent('workbook.xlsx')}/workbook/worksheets(@{encodeURIComponent('Sheet1')})/tables",
      "body": {
        "address": "A1",
        "hasHeaders": true,
        "values": "@body('Format_ReportData')"
      }
    }
  }
}
```

#### Option B: Send Email Report
```json
{
  "Send_Email_Report": {
    "type": "ApiConnection",
    "inputs": {
      "host": {
        "connectionName": "office365"
      },
      "method": "post",
      "path": "/v2/Mail",
      "body": {
        "To": "@{variables('ManagerEmail')}",
        "Subject": "Manager Reports - @{body('Get_Manager')?['displayName']}",
        "Body": "<h2>Direct and Indirect Reports</h2><p>Total Reports: @{length(outputs('Union_AllReports'))}</p><table border='1'>@{body('Format_HTML_Table')}</table>",
        "Importance": "Normal"
      }
    }
  }
}
```

#### Option C: Save to SharePoint
```json
{
  "Create_SharePoint_Item": {
    "type": "ApiConnection",
    "inputs": {
      "host": {
        "connectionName": "sharepointonline"
      },
      "method": "post",
      "path": "/sites/@{encodeURIComponent('your-site')}/lists/@{encodeURIComponent('Manager Reports')}/items",
      "body": {
        "ManagerName": "@{body('Get_Manager')?['displayName']}",
        "TotalReports": "@{length(outputs('Union_AllReports'))}",
        "ReportData": "@{body('Format_ReportData')}",
        "GeneratedDate": "@utcNow()"
      }
    }
  }
}
```

## Error Handling

### Add Error Handling Steps:
```json
{
  "Configure_Run_After": {
    "type": "Scope",
    "actions": {
      "Error_Notification": {
        "type": "ApiConnection",
        "inputs": {
          "host": {
            "connectionName": "office365"
          },
          "method": "post", 
          "path": "/v2/Mail",
          "body": {
            "To": "admin@company.com",
            "Subject": "Power Automate Flow Error - Manager Reports",
            "Body": "Error occurred: @{body('Get_Error_Details')}"
          }
        }
      }
    },
    "runAfter": {
      "Main_Flow_Scope": ["Failed", "TimedOut"]
    }
  }
}
```

## Usage Instructions

### Manual Trigger
1. Go to Power Automate
2. Run the flow manually
3. Enter manager's email address when prompted
4. Flow will generate the report automatically

### Scheduled Trigger
1. Set up recurrence trigger (daily/weekly/monthly)
2. Configure with list of managers to process
3. Reports will be generated automatically

### Integration Options
- **Teams**: Send reports to Teams channels
- **Power BI**: Export data for dashboard visualization  
- **SharePoint**: Store in document libraries
- **Excel**: Create formatted spreadsheets

## Benefits

1. **Time Saving**: Automates manual hierarchy lookups
2. **Accuracy**: Eliminates human error in reporting chains
3. **Scalability**: Can process multiple managers simultaneously
4. **Flexibility**: Multiple output formats and delivery options
5. **Compliance**: Maintains audit trail of organizational structure

## Security Considerations

1. **Permissions**: Ensure proper Graph API permissions
2. **Data Privacy**: Handle employee data according to policy
3. **Access Control**: Limit who can trigger the flow
4. **Audit Logging**: Track flow executions and data access

## Troubleshooting

### Common Issues:
1. **Authentication Errors**: Check Graph API permissions
2. **Missing Data**: Verify user exists in Azure AD
3. **Timeout Issues**: Add pagination for large organizations
4. **Rate Limiting**: Implement retry logic and delays

### Performance Optimization:
- Use batch requests for multiple users
- Implement caching for frequently accessed data
- Add pagination for large result sets
- Use parallel processing where possible

## Extensions

### Possible Enhancements:
1. **Cost Center Analysis**: Add budget and cost data
2. **Skills Matrix**: Include employee skills and certifications
3. **Performance Data**: Integrate with performance management systems
4. **Org Chart Visualization**: Generate visual organization charts
5. **Change Tracking**: Monitor organizational changes over time