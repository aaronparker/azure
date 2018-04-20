<#
    .SYNOPSIS
        Login into an Azure tenant
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True, Position = 0)]
    [String] $Username,

    [Parameter(Mandatory = $False, Position = 1)]
    [String] $Password
)

# Check for AzureRM module
If (!(Get-Module -ListAvailable AzureRM)) {
    Write-Warning "AzureRM module not found. Attempting to install."
    Try {
        If (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
            Write-Verbose "Trusting the repository: PSGallery"
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -Force
        }
        Write-Verbose "Installing the AzureRM module."
        Install-Module AzureRM
    }
    Catch {
        Write-Error "Failed to install the AzureRM module with $_.Exception"
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
    $rmLogin = Login-AzureRmAccount -Credential $cred -ErrorAction SilentlyContinue
}
Catch {
    Write-Error "Failed to log into Azure with $_.Exception"
    Break
}

# Return the Azure login context
If ($rmLogin) {
    Write-Verbose "Successful login to Azure."
    Write-Verbose "Returning context object."
    Write-Output (Set-AzureRmContext -Context $RmLogin.Context)
}
Else {
    Write-Warning "Unable to set Azure login context."
}
