# Windows 
This Lab is 1-Tier PKI, 2 Windows 2025 Servers,
Demonstrating Installation and Setup precedure for NON-PRODUCTION READY Environment.

This lab is performed in Proxmox Environment, 
under VLAN 30, subnet 192.168.30.1/24.

# DC01 - Windows Server 2025
This Server will act as the Top Root Authority in the Hierarchy
It will act as:
1. DHCP server
2. DNS server
3. CA - Certificate Authority server

---
## VM installation
1. downaload Windows Server 2025 ISO and prepare VM with the ISO - 
2. Install Drivers, if required, attach CD with Drivers to see the disk.
3. Setup Administrator user, save the password in secure password manager.
4. Install Active-Directory Domain Services, DNS and DHCP
>[!NOTE]
> Do not install Certificate Services if you plan to do DC promotion, it'll block the promotion.
6. Configure DNS - We're using be using FQDN and delegate the subdomain to our Windows DNS service - https://developers.cloudflare.com/dns/manage-dns-records/how-to/subdomains-outside-cloudflare/
5. Promote to Domain Controller.
7. Configure DHCP


# MECM Server - Installation

```bash
mise exec -- bash
cd infra
tofu init
tofu plan
tofu apply
```

Manually Add Another Disk for MECM and SQL server, it sohuld be seperate Disk from the OS. 
give it 70-100GB storage.

## SSH via keys:
1. Enable openSSH in server (and set network to private\trusted) 
2. add pub key to 'ProgramData\ssh\administrators_authorized_keys' (UTF-8)
3. run command to allow ssh via keys for Administrators
  ```powershell
  # Only the SYSTEM and Administrators groups should have access
  icacls "$env:ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "NT AUTHORITY\SYSTEM:(R)" /grant "BUILTIN\Administrators:(R)"
  ```
4. if needed, add firewall role or add 'Domain network" to the fw rule to allow ssh access from domain network.


## SCCM01 setup
1. install Windows server 2025
2. join Domain
3. prepare prequesites for MECM 
4. Install SQL and configure admin and sysadmin 
5. 
### Pre-requesites
1. Be Domain Member of the AD DC (DC01) 
2. ~~SQL server (remote or local)~~ tbd - not blocker for next steps

### Join SCCM01 into existing AD domain as member
1. run `join_ad_domain.yml` playbook, it will install and join the server.  
  ```
  cd ansible
  ansible-playbook join_ad_domain.yml
  ```
2. DONE

#### Domain Preperation for MECM onboarding
On DC01
install AD DS extention for MECM (https://www.microsoft.com/en-us/evalcenter/download-microsoft-endpoint-configuration-manager)

1. Unzip and run `BIN\X64\extadsch`
2. confirm success by observing content of the log file produced by the script `C:\ExtADSch`

#### Create Container for "System Management" and give full access for SCCM01
1. Using `adsiedit.msc`, create new container "System Management"
2. Under `Security` of the new container, append permissions for computer "SCCM01" to have full control of the container.
3. Apply the new permission to `This object and all descendant objects` - this is so further customization could be done under the container.
4. ~~replicate to all other Domain Controllers `repadmin /syncall`~~  We have single DC
5. DONE.


### SQL server Installation
On Primary Site
1. Install ODBC Driver 18.6 (18.7 doesnt support latest mecm)(https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server?view=sql-server-ver17)
2. Install OLE DB Driver (https://learn.microsoft.com/en-us/sql/connect/oledb/download-oledb-driver-for-sql-server?view=sql-server-ver17)
3. Install ADK
4. Install ADK-WinPE add-on
5. Add services: IIS
6. add features: `NET3.5->HTTP Activation` and `Remote Differential Compression`
7. Open SQL 1433 port into SCCM01 to allow SQL management remotely
  ```
  New-NetFirewallRule -DisplayName "SQL 1433" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow
  ```
  Open SQL 1434 port into SCCM01 to allow SQL management remotely
  ```
  New-NetFirewallRule -DisplayName "SQL Browser service" -Direction Inbound -Protocol UDP -LocalPort 1434 -Action Allow
  ```
8. create OU `service accounts`, add create user `svc_sql`
9. in SCCM01, add svc_sql to the Administrators group
10. Add seperate Disk for the Databases,DP,etc.. (170GB for lab is enough)
11. install and download the SQLserver2022 - install as standalone - > tick Database Engine Services
12. ensure collation is matching: `SQL_Latin1_General_CP1_CI_AS`
13. Services Account: server agent & server DB engine, put as svc_sql user. put all 3 accounts to automatic
14. Specify SQL server Admins: svc_sql, SCCM01, Administrator, SYSTEM(NT)
15. after installation, confirm sql services on *auto and running* under `services` and MSQLSERVER is running under the 'svc_sql' service account
16. Install visual Studio SSMS 22

#### Optimize SQL server 2022 for SCCM
1. edit tempdb and set following files:
  set tempdev 8GB min, 12GB max
  set templog 8GB min, 12 GB max
2. max degree of parallelism - 1 for each cpu core
3. cost threshold for parallelism - 50

#### setup SPN - Service Principal Name for MECM->SQL Communication
on DC01 create SPN for svc_sql into sccm01,
It will map service into a domain account
mendatory for kerberos to work correctly with MECM.
MECM uses it as Unique ID to Communicate with SQL (via kerberos).

`setspn -A MSSQLSvc/sccm01.corp.toxiclabs.net:1443 CORP\svc_sql`

`setspn -A MSSQLSvc/sccm01.corp.toxiclabs.net CORP\svc_sql` (optional)

`setspn -A MSSQLSvc/sccm01:1443 CORP\svc_sql`

Verify SPN on DC01 and SCCM01
`setspn -L CORP\svc_sql`

### SQL server Configuration manager
enable TCP/IP - under SQL Server network Configuration -> Protocols for MSSQLSERVER
Ein the TCP/IP -> IP addresses -> enable IP2 enabled=yes
restart services: `SQL Server (MSSQLSERVER)` && `SQL Server Browser`

#### Validation
`sqlcmd -S localhost -E` - can connect to SQL

Test AD write ability (cmd) - can communicate with AD
`nltest /dsgetdc:corp.toxiclabs.net`

Actual SQL Query
`SELECT @@VERSION`

### SMSS

#### prerequesites
run the check `prereqchk.exe' under `MECM\SMSSETUP\BIN\X64`
``` shell
cd C:\Users\svc_sql\Downloads\SMSSETUP\BIN\X64
.\prereqchk.exe /Local
```
In SQL server
set memory MAX to 50% of the SCCM01 RAM. (4GB-8GB), 8GB recommended.
set memory MIN to 50% of MAX

enable server role: IIS 6 Management Compatibility & WMI Compitability
enable feature: BITS-> IIS Server Extention
Install and enable BITS - mendatory for MP and DP


### install MECM 2509 (for 2605 ,sqlserver2025 can be used )
this guide is for Standalone Primary Site.

1. in SQL server, set compitability level to 150
```SQL
 USE master;
 GO

 ALTER DATABASE [model] SET COMPATIBILITY_LEVEL = 150;

-- comfirm level --
SELECT name, compatibilty_level
FROM sys.databases
WHERE name = 'model';

 -- Expected result is 150 (2019 level), not 160 (2022 level)
```
2. restart SQL services for database isntance

### Configuration Manager setup
3. run `SMSSetup/BIN/X64/setup.exe` *Dont tick `use typical ..`, we configured all manually*
4. set site information (hard\impossible to change afterwards)
site code: LAB
site name: Toxiclabs Lab  
Tick -  install the Configuration Manager Console 
DONT put the installation folder to the OS drive. 
5. change installation drive letter to the other drive.
6. choose `install as standalone`
7. change service broker port to `4022` (NOT the same as SQL server)
8. Client Communication settings: choose `Configure the communication method on each site` and *Tick* `clients will use HTTPS when they have valid PKI..` 
9. Choose connection method to `EHTTP` for the DP & MP, we will change to HTTPS later.
10. Service Connection Point  Setup - Choose  `skip for now`, we dont need delivery via update services\internet

Reporting Service is crucial part for MP and DP, itll be used to report if our installation of notepad++ was successful.
1.Laucnh v_smss.exe installer
2. SQL server -> Modify -> Indevidual components -> sql server reporting service


#### Configuration Manager - Post Installation configuration
currently only svc_sql have Permissions to operate the Configuration Manager,
we will add CORP\Adminisatrator to have access too. later it could be locked down.

1. Launch Configuration Manager Console
2. Choose our Lab, if it wasnt connected automatically.
3. Administration -> Security -> Administrative Users -> add User or Group -> CORP\Administrator, Security Scope set to `ALL`

Enable Discovery of Forests, Systems and Users.
1. Configuration Manager -> Administration -> Hierarchy Methods -> Discovery Methods
2. Enable Forest Discovery -> tick all three options
3. Enable System Discovery -> choose the full AD top level object
4. Enable User Discovery -> add top level domain, Tick Discover onjects withing AD groups
5. Confirm you see subnet under Administration->boundery.
6. if not create subnet udner DC01->AD sites -> sites - > subnets -> create our subnet here.
7. on SCCM01 create boundery group with the newly created boundery subnet.
8. under Administration -> Site Configuration -> Servers and Site System Roles -> our site -> Distribution point -> properties -> boundery groups and add our Boundery Group.
9. ~~also enable PXE deilvery, all and unknow.~~
10. ~~Set password for the PXE.~~



On CA server DC01, add Web-server certificate Template
1. Launch Certificate Authority - > corp-DC01-CA -> Certificate Templates -> R click -> new Cert template to issue -> Web Server
2. Add SCCM01 to enroll permissions of this certificate: Certificate Templates console -> Web Server -> Properties -> Security Groups -> tick cumputer and add SCCM01.

On SCCM01, request new Personal Certificate (Local computer):
1. Open mmc.exe -> File Add snap-in -> Certificate -> Local Comp -> Personal -> Certificates -> Request new Certificate -> Web Server

#### Deploying MECM Agents across machines
There's serval methods to install the agent Across machines and agents, 
1. Manual installation.
2. GPO deployment
3. Client Push installation.

For this lab we will utilize two approaches, Manual and Client Push. 
##### SCCM01 - Client push installation
1. Navigate Microsoft Configuration Manager -> Assets and Compliance -> Devices
2. Right Click on `SCCM01` -> Install Client
2. observe installation progress and log: `C:\Windows\ccmsetup\Logs\ccmsetup.log`, successful installation will end with "CcmSetup is exiting with return code 0"
3. Confirm agent have all expected Actions access via Control Panel -> Configuration Manager -> Actions, The list composed of more than 2 Actions.


##### DC01 - Manual Installation
1. execute: `\\SCCM01\SMS_LAB\Client\ccmsetup.exe`
2. observe installation progress and log: `C:\Windows\ccmsetup\Logs\ccmsetup.log`, successful installation will end with "CcmSetup is exiting with return code 0"
3. Confirm agent have all expected Actions access via Control Panel -> Configuration Manager -> Actions, The list composed of more than 2 Actions.

#### Adding Notepad++ and deploying it to DC01&SCCM01
Before we can Configure our MECM to install softwares, we need a method to deliver and make the installation files accesible to our Machines.
We will create a folder `Sources` and will share it with our domain systems.
1. Create folder `Sources`, share it with `Administrator`.
2. Copy notepad++.msi into this folder.
3. confirm its accesible on DC01.

* Add notepad++ Application to MECM
1. Microsoft Configuration manager -> Software Library -> Application Management -> Applications
2. Right Click -> Create Installation -> msi -> point to our network shared msi installer -> next till end. 

* Deploy Application to our group (DC01 & SCCM01)
1. NotePad++ -> Right Click -> Deploy -> Collection -> choose 'Device Collections' -> All desktop and servers -> next..
2. Make the deployment Mandatory for auto installation 

Observe Installation via the Deployments tab under Notepad++ application.
