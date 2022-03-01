# oracle_directory_transfer
#### uploads or downloads files to/from oracle database directory
* [ora_dir_transfer.ps1](#powershell-script-ora_dir_transferps1)
* [sqlcl_ora_dir_download.js](#sqlcl-script-sqlcl_ora_dir_downloadjs)

Sometimes you may need to copy files from or to the Oracle directory.
It is easy when you have direct access to the database server's file system.
It is a little bit tricky when you don't (AWS RDS instance for example).
One way to accomplish this is to create database link between the existing database (the one you have access to) and the target db 
 and use [DBMS_FILE_TRANSFER](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_FILE_TRANSFER.html) package to copy files between instances.

---

### powershell script: ora_dir_transfer.ps1

Here is another solution which doesn't require the second database.
It is a powershell script [ora_dir_transfer.ps1](https://github.com/anilech/oracle_directory_transfer/blob/627b68f6733ca593c2e48b1a86ea99ff7fc48f78/ora_dir_transfer.ps1) which uses [ODAC](https://www.oracle.com/technetwork/topics/dotnet/downloads/odacdeploy-4242173.html) to access the database and then [UTL_FILE](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/UTL_FILE.html) package to read/write files on the database server.
It is influenced by [this perl script](https://stackoverflow.com/questions/29431398/perl-script-to-download-raw-files-from-amazon-oracle-rds).
You may need to fix Oracle dll path on the "[Reflection.Assembly]::LoadFile" line.

#### Run it like this:
```
c:\> powershell -executionpolicy bypass -file "ora_dir_transfer.ps1" ^
 -get ^
 -file c:\temp\dump.dmp ^
 -ora_dir DATA_PUMP_DIR ^
 -database mydbhost/orcl ^
 -username system/manager
```
This will copy the dump.dmp from the DATA_PUMP_DIR to the c:\temp

#### Mandatory parameters are:
`-get` | `-put`: download the `-file <filename>` from the DB or upload the file to the DB  
`-ora_dir`: oracle directory name, check the [ALL_DIRECTORIES](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_DIRECTORIES.html) view if unsure.  
`-database`: connection string to the DB.  
`-username`: db credentials. (user/password)  
Optional parameters are:  
`-move`: delete source file after the transfer  
`-force`: owerwrite existing files  

---

### sqlcl script: sqlcl_ora_dir_download.js
The [sqlcl](https://www.oracle.com/database/technologies/appdev/sqlcl.html) is the new fat sqlplus written in java, therefore it supports a bunch of platforms.
It also runs javascript natively, so it is possible to execute quite powerfull scripts with it.
The [sqlcl_ora_dir_download.js](https://github.com/anilech/oracle_directory_transfer/blob/f8931b5d059b79015950ef79ff66080c8c89390f/sqlcl_ora_dir_download.js)
script works in a download-mode only, but it doesn't require the UTL_FILE's grant.

To use the script you need to connect to the database with the SQLcl first. Then execute it with the `SCRIPT` command.
#### Parameters are:
 `-d` or `--directory` - oracle directory to download from  
 `-f` or `--file`      - filename to download  
 `-m` or `--move`      - delete source file after the transfer  
 `-o` or `--overwrite` - overwrite local file if it exists

#### examples:
```
C:\>sql /nolog
SQLcl: Release 21.4 Production

Copyright (c) 1982, 2022, Oracle.  All rights reserved.

SQL> connect usr@db
Password? (**********?) ***
Connected.
SQL> script sqlcl_ora_dir_download.js -d ORADIR -f dump.dmp
OK: dump.dmp (152219648 bytes in 3.9 secs, 36.83 MB/s)
SQL> exit
```

It is impossible to run it from command line using the standard `@` option. So if you need to run it that way, you can use pipe:
```
C:\>echo script sqlcl_ora_dir_download.js -d ORADIR -f dump.dmp -o | sql -l -s usr/pwd@db

OK: dump.dmp (152219648 bytes in 4 secs, 36.26 MB/s)
```
