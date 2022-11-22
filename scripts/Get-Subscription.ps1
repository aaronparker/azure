<#
    .SYNOPSIS
        Login into an Azure tenant
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True, Position = 0)]
    [System.String] $Username,

    [Parameter(Mandatory = $False, Position = 1)]
    [System.String] $Password
)

# Check for Az module
If (!(Get-Module -ListAvailable Az)) {
    Write-Warning "Az module not found. Attempting to install."
    Try {
        If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
            Write-Verbose "Trusting the repository: PSGallery"
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
        Write-Verbose "Installing the Az module."
        Install-Module Az
    }
    Catch {
        Write-Error "Failed to install the Az module with $_.Exception"
    }
}

# Get credentials
If ($Password) {
    Write-Verbose "Creating a credential object with $Username."
    $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $securePassword
}

If (!($cred)) {
    Try {
        Write-Verbose "Prompt for credentials."
        $cred = Get-Credential -UserName $UserName -Message "Enter Azure credentials" -ErrorAction SilentlyContinue
    }
    Catch {
        Write-Error "Failed to get credentials with $_.Exception"
        Break
    }
}

# Login to the Azure tenant
Try {
    Write-Verbose "Logging into Microsoft Azure."
    $rmLogin = Login-AzAccount -Credential $cred -ErrorAction SilentlyContinue
}
Catch {
    Write-Error "Failed to log into Azure with $_.Exception"
    Break
}

# Return the Azure login context
If ($rmLogin) {
    Write-Verbose "Successful login to Azure."
    Write-Verbose "Returning context object."
    Write-Output (Set-AzContext -Context $RmLogin.Context)
}
Else {
    Write-Warning "Unable to set Azure login context."
}
