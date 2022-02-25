# CREATED: Alexey Anisimov https://anilech.github.io/
# PURPOSE: transfer files to and from Oracle database directories.
# PARAMETERS:
#  -get: transfer data from the remote database to the local file
#  -put: transfer data from the local file to the remote database
#  -move: delete source file after the transfer (optional)
#  -force: overwrite existing files (optional)
#  -database: db connection string (TNSENTRY/EZCONNECT)
#  -username: username/password to connect to DB
#  -ora_dir: Oracle Directory name (select * from all_directories)
#  -file: filename to transfer.
# EXAMPLE:
#  powershell -executionpolicy bypass -file "ora_dir_transfer.ps1" -get -file c:\dump.dmp -ora_dir DATA_PUMP_DIR -database mydbhost/orcl -username system/manager
#  will transfer file dump.dmp from Oracle DATA_PUMP_DIR to the local c:\dump.dmp
param (
  [Parameter(Mandatory=$true)][string]$database = "localhost/xe",
  [Parameter(Mandatory=$true)][string]$username = "usr/pwd",
  [Parameter(Mandatory=$true)][string]$ora_dir = "ORADIR",
  [Parameter(Mandatory=$true)][string]$file = "dump.dmp",
  [switch]$get = $false,
  [switch]$put = $false,
  [switch]$move = $false,
  [switch]$force = $false
)
$ErrorActionPreference = "Stop"

if ($get -eq $put) {write-error "run mode (-get) or (-put) should be specified (but not both)"; exit}

# ODAC is here "https://www.oracle.com/technetwork/topics/dotnet/downloads/odacdeploy-4242173.html"
[Reflection.Assembly]::LoadFile("C:\oraclexe\app\oracle\product\11.2.0\server\odp.net\bin\4\Oracle.DataAccess.dll") | out-null
 
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

function execSQL() { param([string]$mode="")
  $cmd.Parameters.Add("f_id", $f.id);
  $cmd.Parameters.Add("f_dt", $f.dt);
  $cmd.Parameters.Add("f_bm", $f.bm);
  if       ($mode -eq "OPEN") {
    $cmd.Parameters["f_id"].Direction="InputOutput";
    $cmd.Parameters["f_dt"].Direction="InputOutput";
    $cmd.Parameters["f_bm"].Direction="InputOutput";
    $cmd.Parameters.Add("fn", [System.IO.Path]::GetFileName($file));
    $cmd.Parameters.Add("dn", $ora_dir);
    $cmd.Parameters.Add("m", $(if ($get) {"rb"} else {"wb"}));
  } elseif ($mode -eq "DATA") {
    $cmd.Parameters.Add("data", $data);
    $cmd.Parameters["data"].Direction=$(if ($get) {"Output"} else {"Input"});
    $cmd.Parameters["data"].Size=$chunk+1;
    $cmd.Parameters["data"].OracleDbType="RAW";
  } elseif ($mode -eq "REMOVE") {
    $cmd.Parameters.Add("fn", [System.IO.Path]::GetFileName($file));
    $cmd.Parameters.Add("dn", $ora_dir);
  } elseif ($mode -eq "ATTR") {
    $cmd.Parameters.Add("fn", [System.IO.Path]::GetFileName($file));
    $cmd.Parameters.Add("dn", $ora_dir);
    $cmd.Parameters.Add("fe", 0); $cmd.Parameters["fe"].Direction="Output";
    $cmd.Parameters.Add("fl", 0); $cmd.Parameters["fl"].Direction="Output";
    $cmd.Parameters.Add("bs", 0); $cmd.Parameters["bs"].Direction="Output";
  }
  $cmd.ExecuteNonQuery();
  if       ($mode -eq "OPEN") {
    $script:f.id=$cmd.Parameters["f_id"].Value;
    $script:f.dt=$cmd.Parameters["f_dt"].Value;
    $script:f.bm=$cmd.Parameters["f_bm"].Value;
  } elseif (($mode -eq "DATA") -and ($get)) {
    $script:br=$cmd.Parameters["data"].Size;
    if ($br -gt 0) {$script:data=$cmd.Parameters["data"].Value;}
  } elseif ($mode -eq "ATTR") {
    $script:ora_fe=$(if ($cmd.Parameters["fe"].Value -eq 0) {$false} else {$true});
    $script:ora_fl=$cmd.Parameters["fl"].Value;
  }
  $cmd.Parameters.Clear();
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

function fixBytes($n) {
  $suff = "B","KB","MB","GB","TB","PB","EB","ZB","YB"
  $indx = 0; while ($n -gt 1kb) { $n=$n/1kb; $indx++}
  "{0:N1} {1}" -f $n, $suff[$indx]
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

function checkAttr() {
  $cmd = New-Object Oracle.DataAccess.Client.OracleCommand($sql_attr,$conn);
  $cmd.BindByName = $True;
  execSQL "ATTR" | out-null;
  $cmd.Dispose();
}

## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##


$chunk=32767
$sql_prfx = "DECLARE f utl_file.file_type; BEGIN f.id := :f_id; f.datatype := :f_dt; f.byte_mode := :f_bm = 1; ";
$sql_open = "$($sql_prfx) f := utl_file.fopen(:dn, :fn, :m, NULL); :f_id := f.id; :f_dt := f.datatype; :f_bm := case when f.byte_mode then 1 else 0 end; END;";
$sql_data = "$($sql_prfx) utl_file.$(if ($get) {'get'} else {'put'})_raw(f, :data, $(if ($get) {$chunk} else {'true'})); exception when NO_DATA_FOUND then null; END;";
$sql_fcls = "$($sql_prfx) utl_file.fclose(f); END;";
$sql_frem = "$($sql_prfx) utl_file.fremove(:dn, :fn); END;";
$sql_attr = "$($sql_prfx) declare fe boolean; begin utl_file.fgetattr(:dn, :fn, fe, :fl, :bs); :fe := case when fe then 1 else 0 end; end; END;";
$f=@{"id"=0;"dt"=0;"bm"=0}
$ora_fe=$false
$ora_fl=0
try {
  $constr = "User Id=$($username -replace '/.*','');Password=$($username -replace '^[^/]*/','');Data Source=$($database)"
  write-warning $constr
  $conn= New-Object Oracle.DataAccess.Client.OracleConnection($constr)
  $conn.Open()

  checkAttr
  if ($get) {
    if (!($ora_fe)) {write-error "'$($ora_dir):$([System.IO.Path]::GetFileName($file))' not found!"}
    if (Test-Path $file) { if ($force) {write-warning "local file '$($file)' exists and will be overwritten."}
                                  else {write-error "local file '$($file)' already exists. Use '-force' to overwrite." } }
  } else {
    if (!(Test-Path $file)) { write-error "local file '$($file)' not found!"; }
    if ($ora_fe) { if ($force) {write-warning "remote file '$($ora_dir):$([System.IO.Path]::GetFileName($file))' exists and will be overwritten."}
                          else {write-error "remote file '$($ora_dir):$([System.IO.Path]::GetFileName($file))' already exists. Use '-force' to overwrite." } }
    $ora_fl=$(Get-ItemProperty $file).Length
  }
  if ($ora_fl -eq 0) { write-warning "source file is empty" }
  $cmd = New-Object Oracle.DataAccess.Client.OracleCommand($sql_open,$conn); $cmd.BindByName = $True;
  execSQL "OPEN" | out-null;
  $cmd.Dispose();

  if ($get) {
    echo "downloading '$($ora_dir):$([System.IO.Path]::GetFileName($file))' from DB '$($database)' to '$($file)':"
    if (Test-Path $file) { rm $file }
    $sio = New-Object System.IO.BinaryWriter([System.IO.File]::Open($file, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite))
  } else {
    echo "uploading '$($file)' to '$($ora_dir):$([System.IO.Path]::GetFileName($file))' on DB '$($database)':"
    $sio = New-Object System.IO.BinaryReader([System.IO.File]::Open($file, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite))
  }
  $cmd = New-Object Oracle.DataAccess.Client.OracleCommand($sql_data,$conn); $cmd.BindByName = $True;
  $flen=0;
  $data = new-object byte[] $chunk;
  $br=$chunk;
  $d1=get-date
  $d3=$d1; $flen_d=$flen;
  while (($br -eq $chunk) -and ($ora_fl -gt 0)) {
    if ($get) { execSQL "DATA" | out-null; $sio.Write([byte[]]$data,0,$br) }
         else { $data=$sio.Readbytes($chunk); $br=$data.length; if ($br -gt 0) {execSQL "DATA" | out-null}};
    $flen+=$br;
   
    if ( $($($(get-date) - $d3).TotalSeconds) -gt 1 ) { # report progress every second
      Write-Progress -Activity "Transfer $([System.IO.Path]::GetFileName($file))" -Status "current speed $(fixBytes $(($flen-$flen_d)/$($(get-date)-$d3).TotalSeconds))/s" -PercentComplete $($flen/$ora_fl*100)
      $d3=get-date; $flen_d=$flen;
    }
  }
  $d2=[int]$($($(get-date)-$d1).TotalSeconds); if ($d2 -lt 1) {$d2=1}
  echo $("$($file): transferred $($flen) bytes ($(fixBytes $flen)) " +
        "in $($d2) seconds ($(fixBytes $($flen/$d2))/s).")

  $cmd.Dispose();
  $cmd = New-Object Oracle.DataAccess.Client.OracleCommand($sql_fcls,$conn);
  $cmd.BindByName = $True;
  execSQL "CLOSE" | out-null;
  $cmd.Dispose();
  $sio.Close();
 
  if ($put) {
    checkAttr; if (!($ora_fe)) {
     write-error "'$($ora_dir):$([System.IO.Path]::GetFileName($file))' not found!"}
  }
  if (!($ora_fl -eq $flen)) {
     write-error "'$($ora_dir):$([System.IO.Path]::GetFileName($file))' size $($ora_fl) doesn't match the transferred size $($flen)"}

  if ($move) {
    write-warning "removing source..."
    if ($get) {
      $cmd = New-Object Oracle.DataAccess.Client.OracleCommand($sql_frem,$conn);
      $cmd.BindByName = $True;
      execSQL "REMOVE" | out-null;
      $cmd.Dispose();
    }
    else { if (Test-Path $file) { rm $file } }
  }
}
finally {
  if ($cmd -ne $null) { $cmd.Dispose(); }
  if ($conn -ne $null) {$conn.Close(); $conn.Dispose(); }
  if ($sio -ne $null) { $sio.Close(); }
}
