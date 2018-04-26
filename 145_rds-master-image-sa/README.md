# RDSH Master Image - Storage Account

Deploys a Windows Server 2016 VM to create an RDSH master image using Standard storage on a Storage Account. Configures the VM with a configuration script to add/remove roles and features, install applications and configure the default user experience.

## Requirements

Uses secrets in a Key Vault for the following:

- VM local administrator username (LocalUser)
- VM local administrator password (LocalPassword)
- Share containing applications (AppShare)
- Username to authenticate to the share (domainUser)
- Password to authenticate to the share (domainPass)

These values are passed to parameters for `configureRDS.ps1` to enable configuration of the VM and installation of applications. The referenced Key Vault should look like this:

[![Key vault](https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/img/secrets.png)](https://raw.githubusercontent.com/aaronparker/build-azure-lab/master/img/secrets.png)

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)
