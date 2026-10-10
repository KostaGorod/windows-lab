

## Insallation of Windows Server 2025 Domain-Controller
1. downalod image and prepare VM with the ISO
2. setup Admin user, AD DS *!DO NOT INSTALL Certificate-Services before DC promotion!*
3.


mise exec -- bash
cd infra
tofu init
tofu plan
tofu apply


## SSH via keys:
1. Enable openSSH in server (and set network to private\trusted) 
2. add pub key to 'ProgramData\ssh\administrators_authorized_keys'
3. run command to allow ssh via keys for Administrators
  ```
  # Only the SYSTEM and Administrators groups should have access
  icacls "$env:ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "NT AUTHORITY\SYSTEM:(R,W)" /grant "BUILTIN\Administrators:(R,W)"
  ```
4. DONE


## SCCM01 setup
1. install Windows server 2025
2. join Domain
3. prepare prequesites for MECM 
### 
1. enter ansible folder
2. enter server details of `SCCM01` under `inventory.ini` (fqdn, IP, ssh-key)
### 2. Join existing AD domain as member
1. run `join_ad_domain.yml` playbook, it will install and join the server.  
  ```
  cd ansible
  ansible-playbook join_ad_domain.yml
  ```
4.
