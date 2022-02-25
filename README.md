# oracle_directory_transfer
uploads or downloads files to/from oracle database directory

Sometimes you may need to copy files from or to the Oracle directory.
It is easy when you have direct access to the database server's file system.
It is a little bit tricky when you don't (AWS RDS instance for example).
One way to accomplish this is to create database link between the existing database (the one you have access to) and the target db 
 and use [DBMS_FILE_TRANSFER](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_FILE_TRANSFER.html) package to copy files between instances.

Here is another solution which doesn't require the second database.
It is a powershell script [ora_dir_transfer.ps1](https://github.com/anilech/oracle_directory_transfer) which uses [ODAC](https://www.oracle.com/technetwork/topics/dotnet/downloads/odacdeploy-4242173.html) to access the database and then [UTL_FILE](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/UTL_FILE.html) package to read/write files on the database server.
It is influenced by [this perl script](https://stackoverflow.com/questions/29431398/perl-script-to-download-raw-files-from-amazon-oracle-rds).
You may need to fix Oracle dll path on the "[Reflection.Assembly]::LoadFile" line.

Run it like this:

```
c:\> powershell -executionpolicy bypass -file "ora_dir_transfer.ps1" ^
 -get ^
 -file c:\oracle\dump.dmp ^
 -ora_dir DATA_PUMP_DIR ^
 -database mydbhost/orcl ^
 -username system/manager
```

#### Mandatory parameters are:
-get | -put: download file from db | upload file to db  
-ora_dir: oracle directory name, check the ALL_DIRECTORIES view if unsure.  
-database: connection string to the DB.  
-username: db credentials. (user/password)  
Optional parameters are:  
-move: delete source file after the transfer  
-force: owerwrite existing files  

