#Requires -Version 5.1

# ============================================================================
# Aladin to Varion Time-Off Sync Script
# ============================================================================
# This script syncs time-off records from a local SQL Server database
# to the Varion API. Configure the variables below before running.
# ============================================================================

# --- CONFIGURATION (modify these values) ---
$SqlServer = "localhost"                    # SQL Server instance (e.g., "localhost", ".\SQLEXPRESS")
$Database = "YOUR_DATABASE_NAME"            # Database name - MUST BE SET
$TableName = "PlanOtp"                      # Table name to query
$ApiToken = "YOUR_API_TOKEN"                      # Varion API token - MUST BE SET

# SQL Server Authentication (leave empty to use Windows Authentication)
$SqlUsername = ""                           # SQL Server username (e.g., "sa")
$SqlPassword = ""                           # SQL Server password

# --- OPTIONAL: Override config from external file if it exists ---
$ConfigPath = Join-Path $PSScriptRoot "config.ps1"
if (Test-Path $ConfigPath) {
    . $ConfigPath
}

# --- LOGGING SETUP ---
$LogDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$LogFile = Join-Path $LogDir "sync-$(Get-Date -Format 'yyyy-MM-dd').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Host $LogEntry
}

# --- API CONFIGURATION ---
$ApiBaseUrl = "https://api.varion.looming.tech/api/public/employees/timeoff"
$ApiUrl = "${ApiBaseUrl}?token=${ApiToken}"

# --- MAIN SCRIPT ---
Write-Log "Starting Aladin to Varion sync..."

try {
    # Validate configuration
    if ($Database -eq "YOUR_DATABASE_NAME") {
        throw "Database name not configured. Please set the `$Database variable."
    }

    # Build connection string
    if ($SqlUsername -and $SqlPassword) {
        # SQL Server Authentication
        $ConnectionString = "Server=$SqlServer;Database=$Database;User Id=$SqlUsername;Password=$SqlPassword;TrustServerCertificate=True;"
        Write-Log "Connecting to SQL Server: $SqlServer, Database: $Database (SQL Auth)"
    } else {
        # Windows Authentication
        $ConnectionString = "Server=$SqlServer;Database=$Database;Integrated Security=True;TrustServerCertificate=True;"
        Write-Log "Connecting to SQL Server: $SqlServer, Database: $Database (Windows Auth)"
    }

    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()

    # --- Query Annual Leave (PlanOtp) ---
    $Query = "SELECT id, dat1, dat2, approved, typeotp, Comments, CreationDate FROM $TableName"
    $Command = New-Object System.Data.SqlClient.SqlCommand($Query, $Connection)
    $Adapter = New-Object System.Data.SqlClient.SqlDataAdapter($Command)
    $DataSet = New-Object System.Data.DataSet
    $Adapter.Fill($DataSet) | Out-Null

    $LeaveRecords = $DataSet.Tables[0].Rows
    Write-Log "Retrieved $($LeaveRecords.Count) annual leave records from $TableName"

    # --- Query Sick Leave (BOLN) ---
    $BolnQuery = "SELECT ID, DAT1, DAT2, Zapoved, TYPEBOLN, DateInput FROM BOLN"
    $BolnCommand = New-Object System.Data.SqlClient.SqlCommand($BolnQuery, $Connection)
    $BolnAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($BolnCommand)
    $BolnDataSet = New-Object System.Data.DataSet
    $BolnAdapter.Fill($BolnDataSet) | Out-Null

    $SickRecords = $BolnDataSet.Tables[0].Rows
    Write-Log "Retrieved $($SickRecords.Count) sick leave records from BOLN"

    $Connection.Close()

    $TotalRecords = $LeaveRecords.Count + $SickRecords.Count

    if ($TotalRecords -eq 0) {
        Write-Log "No records to sync. Exiting."
        exit 0
    }

    # Transform data to API format
    $TimeOffData = @()

    # Annual leave records
    foreach ($Row in $LeaveRecords) {
        $StartDate = [DateTime]$Row["dat1"]
        $EndDate = [DateTime]$Row["dat2"]
        $CreatedAt = [DateTime]$Row["CreationDate"]

        $TimeOffData += @{
            year       = $StartDate.Year
            id         = [int]$Row["id"]
            start_date = $StartDate.ToString("yyyy-MM-dd")
            end_date   = $EndDate.ToString("yyyy-MM-dd")
            type       = [int]$Row["typeotp"]
            approved   = [int]$Row["approved"]
            comments   = if ($null -eq $Row["Comments"]) { "" } else { [string]$Row["Comments"] }
            created_at = $CreatedAt.ToString("yyyy-MM-ddTHH:mm")
            task_type  = "annual_leave"
        }
    }

    # Sick leave records
    foreach ($Row in $SickRecords) {
        $StartDate = [DateTime]$Row["DAT1"]
        $EndDate = [DateTime]$Row["DAT2"]
        $CreatedAt = if ($null -ne $Row["DateInput"] -and $Row["DateInput"] -isnot [DBNull]) {
            ([DateTime]$Row["DateInput"]).ToString("yyyy-MM-ddTHH:mm")
        } else {
            $StartDate.ToString("yyyy-MM-ddTHH:mm")
        }

        $TimeOffData += @{
            year       = $StartDate.Year
            id         = [int]$Row["ID"]
            start_date = $StartDate.ToString("yyyy-MM-dd")
            end_date   = $EndDate.ToString("yyyy-MM-dd")
            type       = [int]$Row["TYPEBOLN"]
            approved   = [int]$Row["Zapoved"]
            comments   = ""
            created_at = $CreatedAt
            task_type  = "sick_leave"
        }
    }

    # Build API payload
    $Payload = @{
        employees_timeoff_data = $TimeOffData
    } | ConvertTo-Json -Depth 10

    Write-Log "Sending $TotalRecords records to Varion API ($($LeaveRecords.Count) annual leave + $($SickRecords.Count) sick leave)..."

    # Send to API — encode body as UTF-8 bytes so Content-Length matches actual size
    # (PowerShell miscalculates Content-Length when the JSON contains non-ASCII characters)
    $PayloadBytes = [System.Text.Encoding]::UTF8.GetBytes($Payload)

    $Response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Body $PayloadBytes -ContentType "application/json; charset=utf-8"

    Write-Log "API Response: $($Response | ConvertTo-Json -Compress)"
    Write-Log "Sync completed successfully!"

} catch {
    Write-Log "ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
