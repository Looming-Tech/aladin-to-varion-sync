# Aladin to Varion Time-Off Sync

Syncs time-off records from a local SQL Server database to the Varion API.

## Quick Start

1. **Configure**: Edit `config.ps1` and set your database name:
   ```powershell
   $SqlServer = "localhost"           # Your SQL Server instance
   $Database = "YourDatabaseName"     # REQUIRED: Set this
   $TableName = "PlanOtp"             # Table name (default: PlanOtp)

   # For SQL Server Authentication (instead of Windows Auth):
   $SqlUsername = "your_username"     # Leave empty for Windows Auth
   $SqlPassword = "your_password"
   ```

2. **Test manually**:
   ```powershell
   .\sync-timeoff.ps1
   ```

3. **Set up Task Scheduler** (see below)

## Files

| File | Description |
|------|-------------|
| `sync-timeoff.ps1` | Main sync script |
| `config.ps1` | Configuration (database, API settings) |
| `logs/` | Log files (created automatically) |

## Data Mapping

| SQL Column (PlanOtp) | API Field |
|---------------------|-----------|
| id | id |
| dat1 | start_date |
| dat2 | end_date |
| approved | approved |
| typeotp | type |
| Comments | comments |
| CreationDate | created_at |

## Task Scheduler Setup (Windows)

To run the sync automatically every 5 minutes:

1. Open **Task Scheduler** (search "Task Scheduler" in Start menu)

2. Click **Create Task** (not "Create Basic Task")

3. **General tab**:
   - Name: `Aladin to Varion Sync`
   - Select "Run whether user is logged on or not"
   - Check "Run with highest privileges"

4. **Triggers tab**:
   - Click "New..."
   - Begin the task: "On a schedule"
   - Settings: Daily, Start: today at 00:00:00
   - Check "Repeat task every: **5 minutes**"
   - For a duration of: **Indefinitely**
   - Check "Enabled"

5. **Actions tab**:
   - Click "New..."
   - Action: "Start a program"
   - Program/script: `powershell.exe`
   - Add arguments: `-ExecutionPolicy Bypass -File "C:\path\to\sync-timeoff.ps1"`
   - (Replace `C:\path\to\` with actual path)

6. **Settings tab**:
   - Check "Allow task to be run on demand"
   - Check "If the task fails, restart every: 1 minute"
   - Attempt to restart up to: 3 times

7. Click **OK** and enter your Windows credentials

## Logs

Logs are stored in the `logs/` folder with daily rotation:
- `logs/sync-2026-01-14.log`

Check logs to verify successful syncs or troubleshoot issues.

## Troubleshooting

**"Database name not configured"**
- Edit `config.ps1` and set the `$Database` variable

**"Cannot connect to SQL Server"**
- Verify SQL Server is running
- Check the `$SqlServer` value (try `.\SQLEXPRESS` for SQL Express)
- If using Windows Auth: ensure the user has database access
- If using SQL Auth: verify username/password are correct

**"API request failed"**
- Check internet connectivity
- Verify the API token is correct
- Check the log file for detailed error messages

**Script doesn't run from Task Scheduler**
- Ensure the path in Task Scheduler is correct
- Check Task Scheduler History for errors
- Verify the user account has database access
