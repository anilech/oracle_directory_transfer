// https://anile.ch
// js.script for the sqlcl (https://www.oracle.com/database/technologies/appdev/sqlcl.html)
// download files from an oracle directory without direct server access
// command line usage example:
// echo script sqlcl_ora_dir_download.js -d ORADIR -f dump.dmp | sql -l -s usr/pwd@db
"use strict";

// --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

function usage() {
  ctx.write("usage: script sqlcl_ora_dir_download.js -d <ORACLE_DIRECTORY> -f <file> [-m] [-o]\n");
  ctx.write("  -d|--directory - oracle directory\n");
  ctx.write("  -f|--file      - filename to download\n");
  ctx.write("  -m|--move      - delete source file after the transfer\n");
  ctx.write("  -o|--overwrite - overwrite local file if it exists\n\n");  
  ctx.write("required database permissions:\n");
  ctx.write("  create session + read on directory\n");
  ctx.write("  -m: execute on utl_file + write on directory\n\n");
}

// --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

function doArgs(){
  var file="", directory="", force=false, move=false;
  var skip=true;
  for (var arg in args) {
    if (skip) {skip=false; continue;}
    if      ((args[arg] == "-m")||(args[arg] == "--move"))      { move=true; } 
    else if ((args[arg] == "-o")||(args[arg] == "--overwrite")) { force=true; }
    else if ((args[arg] == "-f")||(args[arg] == "--file"))      { skip=true; if (args[arg+1]) {file=args[arg+1];} }
    else if ((args[arg] == "-d")||(args[arg] == "--directory")) { skip=true; if (args[arg+1]) {directory=args[arg+1];} }
  }
  return {"directory":directory, "file":file, "force":force, "move":move};
}

// --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

function getBFILE(directory,file){
  var bFile=null; //Java.type("oracle.jdbc.OracleBfile");
  var stmt = null, rset = null; 
  try {
    stmt=conn.prepareStatement("select bfilename(?,?) from dual");
    stmt.setString(1,directory); stmt.setString(2,file);
    rset=stmt.executeQuery();
    if (rset.next()) { bFile=rset.getBFILE(1); }
  }
  finally { rset.close(); stmt.close(); }
  if (bFile!=null) {
    if (bFile.fileExists()) { return bFile; }
    else { ctx.write("ERROR: remote file "+directory+":"+file+" does not exist.\n"); }
  }
  else { ctx.write("ERROR: unable to get "+directory+":"+file+".\n"); }
}

// --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

function fremove(directory,file){
  ctx.write("removing remote file "+directory+":"+file+" ... "); 
  util.execute("begin utl_file.fremove(:d,:f); end;",{d:directory,f:file});
  var e=util.getLastException();
  if (e) {ctx.write("FAIL:\n"+e+"\n");} else {ctx.write("success.\n");}
}

// --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

function main() {

  var p=doArgs(); if ( (!p.directory) || (!p.file) ) { usage(); return; }
  var bFile = getBFILE(p.directory, p.file); if (!bFile) { return; }

  var l = bFile.length();
  var path = java.nio.file.FileSystems.getDefault().getPath(p.file);
  var duration=null;

  try {
    bFile.openFile();
    var bs = bFile.getBinaryStream();
    var start=new Date().getTime();
    if (p.force) {java.nio.file.Files.copy(bs,path,java.nio.file.StandardCopyOption.REPLACE_EXISTING);}
            else {java.nio.file.Files.copy(bs,path);}
    duration=(new Date().getTime()-start)/1000;
  } catch (e) { 
    if (e instanceof java.nio.file.FileAlreadyExistsException) {ctx.write("ERROR: file "+path+" exists. Use -o to overwrite.\n");} 
    throw e;
  } finally {bFile.closeFile();}

  if (java.nio.file.Files.exists(path)){
    if (java.nio.file.Files.size(path)==l) {
      ctx.write("OK: "+path+" ("+l+" bytes in "+(+duration.toFixed(1))+" secs, "+(+(l/1024/1024/duration).toFixed(2))+" MB/s)\n");
      if (p.move) { fremove(p.directory,p.file); }
    }
    else {ctx.write("ERROR: "+path+" exists but size does not match.\n");}
  }
  else {ctx.write("ERROR: unable to copy "+p.file+"\n");}
}

// --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

if ( typeof conn !== 'undefined' ) {main();} else {ctx.write("ERROR: not connected to Oracle\n");}
