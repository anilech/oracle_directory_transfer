"use strict";

function usage() {
  ctx.write("usage: script sqlcl_ora_dir_download.js -d <ORACLE_DIRECTORY> -f <file> [-m] [-o]\n");
  ctx.write("  -d|--directory - oracle directory\n");
  ctx.write("  -f|--file      - filename\n");
  ctx.write("  -m|--move      - delete source file after transfer\n");
  ctx.write("  -o|--overwrite - overwrite local file if exists\n\n");  
  ctx.write("database permissions:\n");
  ctx.write("  create session + read on directory\n");
  ctx.write("  -m: execute on utl_file + write on directory\n\n");
}

function main() {

  var file="";
  var directory="";
  var force=false;
  var move=false;     

  for (var arg in args) {
    if (arg == 0) {continue;}
    if      ((args[arg] == "-m")||(args[arg] == "--move"))      { move=true; } 
    else if ((args[arg] == "-o")||(args[arg] == "--overwrite")) { force=true; }
    else if ((args[arg] == "-f")||(args[arg] == "--file"))      { if (args[arg+1]) {file=args[arg+1];} }
    else if ((args[arg] == "-d")||(args[arg] == "--directory")) { if (args[arg+1]) {directory=args[arg+1];} }
  }

  if ( (!directory) || (!file) ) { usage(); return; }

  var bFile = null; //Java.type("oracle.jdbc.OracleBfile");
  var stmt = null; 
  var rset = null; 
  try {
    stmt=conn.prepareStatement("select bfilename(?,?) from dual");
    stmt.setString(1,directory); stmt.setString(2,file);
    rset=stmt.executeQuery();
    if (rset.next()) { bFile=rset.getBFILE(1); }
  }
  finally {
    rset.close();
    stmt.close();
  }
  
  if (bFile!=null) {
    if(bFile.fileExists()){
      var l = bFile.length();
      var path = java.nio.file.FileSystems.getDefault().getPath(file);
      var duration=null;
      try {
        bFile.openFile();
        var bs = bFile.getBinaryStream();
        var start=new Date().getTime();
        if (force) {java.nio.file.Files.copy(bs,path,java.nio.file.StandardCopyOption.REPLACE_EXISTING);}
              else {java.nio.file.Files.copy(bs,path);}
        duration=(new Date().getTime()-start)/1000;
      } catch (e) { 
          if (e instanceof java.nio.file.FileAlreadyExistsException) {ctx.write("ERROR: file "+path+" exists. Use -o to overwrite.\n");} 
          throw e;
      } finally {bFile.closeFile();}
      if (java.nio.file.Files.exists(path)){
        if (java.nio.file.Files.size(path)==l) {ctx.write("OK: "+path+" ("+l+" bytes in "+(+duration.toFixed(1))+" secs, "+(+(l/1024/1024/duration).toFixed(2))+" MB/s)\n")}
        else {ctx.write("ERROR: "+path+" exists but size does not match!\n");}
      }
      else {ctx.write("ERROR: unable to copy "+file+"\n");}
    }
    else { ctx.write("ERROR: file "+directory+":"+file+" does not exist.\n"); } 
  }
  else { ctx.write("ERROR: unable to get "+directory+":"+file+".\n"); }
}

if ( typeof conn !== 'undefined' ) {main();} else {ctx.write("ERROR: not connected to Oracle\n");}
