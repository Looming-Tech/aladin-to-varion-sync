# ============================================================================
# Aladin to Varion Sync - Configuration File
# ============================================================================
# Modify these values according to your environment.
# This file is automatically loaded by sync-timeoff.ps1 if present.
# ============================================================================

# SQL Server connection settings
$SqlServer = "localhost"              # e.g., "localhost", ".\SQLEXPRESS", "SERVER\INSTANCE"
$Database = "YOUR_DATABASE_NAME"      # Your database name - REQUIRED

# SQL Server Authentication (leave BOTH empty to use Windows Authentication)
$SqlUsername = ""                     # e.g., "sa", "app_user"
$SqlPassword = ""                     # SQL Server password

# Table settings
$TableName = "PlanOtp"                # Table containing time-off records

# Varion API settings
$ApiToken = "YOUR_API_TOKEN"
