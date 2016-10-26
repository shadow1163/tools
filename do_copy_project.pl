#! /usr/bin/env perl

use DBI;
use ConfigurationManager;
use strict;

my $conf = new ConfigurationManager();
my $db_name = $conf->getDBName();
my $db_host = $conf->getDBHost();
my $db_user = $conf->getDBUser();
my $db_passwd = $conf->getDBPasswd();

my $db_host = "DBI:mysql:$db_name;host=$db_host";

my $dbh = undef;

eval {
	$dbh = DBI->connect($db_host,$db_user,$db_passwd);
};

if ($@) {
	print("connect database error\n$@\n");
	exit(99);
}

my $original_projectname = 'mainline';
my $projectName = '11.21';
my $productName = 'XTM';
my $productid = '1';

#get originalscriptfolderid
my $sql_cmd = "select id from project where name = '$original_projectname' and productid=$productid";
my $ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
my $original_projectid = $ret->{value}->[0];
#print($ret->{value}->[0]);
#
## check project exists or not
my $sql_cmd = "select id from project where name = '$projectName' and productid=$productid";
my $ret;
eval {
	$ret = query_column_db($sql_cmd);
};
if (defined($ret->{value}->[0])) {
	print("failed, project $projectName is exists\n");
	exit(1);
}

##1 add the project into the table project
$sql_cmd = "insert into `wats`.`project` (name,author,date,productid,summary,comments) values ('$projectName',13,CURRENT_TIMESTAMP,$productid,'','')";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
$sql_cmd = "delete from `wats`.`temp_project` where originalid > 0";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}

$sql_cmd = "select id from project where name = '$projectName' and productid=$productid";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
my $projectid = $ret->{value}->[0];
$sql_cmd = "insert into `wats`.`temp_project` (originalid,originalname,copyid,copyname) values ($original_projectid,'$original_projectname',$projectid,'$projectName')";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
#### end 1

#####2 insert data into scriptfolder
$sql_cmd = "insert into `wats`.`scriptfolder` (name,parentid,productid,comments) values ('$projectName',0,$productid,'')";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
$sql_cmd = "delete from `wats`.`temp_scriptfolder` where originalid > 0";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
$sql_cmd = "select id from scriptfolder where name = '$original_projectname' and parentid=0";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
my $original_scriptfolderid= $ret->{value}->[0];
$sql_cmd = "select id from scriptfolder where name = '$projectName' and parentid=0";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
my $feedback2 = $ret->{value}->[0];
$sql_cmd = "insert into `wats`.`temp_scriptfolder` (originalid,originalname,copyid,copyname) values ($original_scriptfolderid,'$original_projectname',$feedback2,'$projectName')";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
$sql_cmd = "select * from `wats`.`scriptfolder` where FIND_IN_SET(id,`wats`.getscriptChildLst(\"$original_scriptfolderid\"));";
    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }
    my $sth = $dbh->prepare($sql_cmd);
    $sth->execute;
    my $scriptfoldervalue = '';
    #$tmpscriptfoldervalue = '';
my @tmpscriptfoldervalueid;
my @tmpscriptfoldervaluename;
my $i = 0;
    while(my @ary = $sth->fetchrow_array()){
        #print join("\t",@ary),"\n";
	if ($i == 0) {
		$i++;
		next;
	}
	$scriptfoldervalue=$scriptfoldervalue."('$ary[1]',$feedback2,$ary[3],'$ary[4]'),";
	$tmpscriptfoldervalueid[$i] = $ary[0];
	$tmpscriptfoldervaluename[$i] = $ary[1]; 
	$i++;
    }
    $sth->finish();
    $dbh->disconnect();
$scriptfoldervalue =~ s/,$//;
$sql_cmd = "insert into `wats`.`scriptfolder` (name,parentid,productid,comments) values $scriptfoldervalue";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
#
$sql_cmd = "select id from scriptfolder where id > $feedback2";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("error to execute command \"$sql_cmd\"\n");
	exit(1);
}
my $tmpscriptfoldervalue = '';
my $result = $ret->{value};
for($i = 0; $i< $#$result;$i++) {
	$tmpscriptfoldervalue = $tmpscriptfoldervalue . "($tmpscriptfoldervalueid[$i+1],'$tmpscriptfoldervaluename[$i+1]',$result->[$i],'$tmpscriptfoldervaluename[$i+1]'),";
}
$tmpscriptfoldervalue =~ s/,$//;
$sql_cmd = "insert into `wats`.`temp_scriptfolder` values $tmpscriptfoldervalue";
my $ret1 = insert_db($sql_cmd);
if ($ret1->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}

for($i = 0; $i< $#$result;$i++) {
	#print("111---$result->[$i]\n");
	#my $getidsql = "select copyid from `temp_scriptfolder` where originalid in (select parentid from scriptfolder where id in (select originalid from temp_scriptfolder where copyid=$result->[$i]))";
	my $getidsql = "select a.copyid from `temp_scriptfolder` a inner join `scriptfolder` b inner join temp_scriptfolder c on a.originalid = b.parentid and b.id = c.originalid where c.copyid=$result->[$i]";
	my $ret2 = query_column_db($getidsql);
	if ($ret2->{ret} eq 'nok') {
		print("Error to execute command \"$sql_cmd\"\n");
		exit(1);
	}
	#print("222---$ret2->{value}->[0]\n");
	my $updateidsql= "update `scriptfolder` set parentid=".$ret2->{value}->[0]." where parentid=$feedback2 and id =".$result->[$i]."";
	#print("333---$updateidsql\n")
	$ret2 = update_db($updateidsql);
	if ($ret2->{ret} eq 'nok') {
		print("Error to execute command \"$sql_cmd\"\n");
		exit(1);
	}
}

## check result
#print("$feedback2\n");
$sql_cmd = "select count(id) as number from scriptfolder where FIND_IN_SET(id,getscriptChildLst($feedback2))";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("error to execute command \"$sql_cmd\"\n");
	exit(1);
}
print("$ret->{value}->[0]\n");
$sql_cmd = "select count(id) as number from scriptfolder where FIND_IN_SET(id,getscriptChildLst($original_scriptfolderid))";
my $ret1 = query_column_db($sql_cmd);
if ($ret1->{ret} eq 'nok') {
	print("error to execute command \"$sql_cmd\"\n");
	exit(1);
}
print("$ret1->{value}->[0]\n");
if ($ret->{value}->[0] == $ret1->{value}->[0]) {
	print("Add $ret->{value}->[0] records into table[scriptfolder] successfully!\n");
} else {
	print("The scriptfolder number of copied is NOT equal the original number, Please check!\n");
}
#### end step2

## 3 insert data into script
$sql_cmd = "insert into `wats`.`script` (name,author,date,product,project,functional_area,functional_sub_area,scriptfile,testdata,configfile,isselected,comments) select name,author,date,product,$projectid,functional_area,functional_sub_area,scriptfile,testdata,configfile,isselected,comments from `script` where project=$original_projectid";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
$sql_cmd = "delete from `wats`.`temp_script` where originalid > 0";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}

my $wats_prefix=$productName.'_sc_';
my $updateidsql="update `script` set wats_script_id=concat('$wats_prefix',id) where project=$projectid";
$ret = insert_db($updateidsql);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}

$sql_cmd = "select * from `script` where project=$original_projectid";
    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }
    my $sth = $dbh->prepare($sql_cmd);
    $sth->execute;
    my $scriptfoldervalue = '';
my @selectoriginalscriptresultid;
my @selectoriginalscriptresultname;
my $i = 0;
    while(my @ary = $sth->fetchrow_array()){
	$selectoriginalscriptresultid[$i] = $ary[0];
	$selectoriginalscriptresultname[$i] = $ary[2];
	$i++;
    }
    $sth->finish();
    $dbh->disconnect();
$sql_cmd = "select * from `script` where project=$projectid";
    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }
    my $sth = $dbh->prepare($sql_cmd);
    $sth->execute;
    my $scriptfoldervalue = '';
my @selecttargetscriptresultid;
my @selecttargetscriptresultname;
$i = 0;
    while(my @ary = $sth->fetchrow_array()){
	$selecttargetscriptresultid[$i] = $ary[0];
	$selecttargetscriptresultname[$i] = $ary[2];
	$i++;
    }
    $sth->finish();
    $dbh->disconnect();
my $temp_scriptresult = 'insert into `temp_script` (originalid,originalname,copyid,copyname) values ';
for(my $j=0;$j<=$#selecttargetscriptresultid;$j++){
	$temp_scriptresult = $temp_scriptresult. "($selectoriginalscriptresultid[$j],'$selectoriginalscriptresultname[$j]',$selecttargetscriptresultid[$j],'$selecttargetscriptresultname[$j]'),";
}
$temp_scriptresult =~ s/,$//;
#print($temp_scriptresult);
$ret = insert_db($temp_scriptresult);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$temp_scriptresult\"\n");
	exit(1);
}

#####update scriptfile
my $updateconfigfilesql="update `script` set `scriptfile` = replace(`scriptfile`,'$original_projectname','$projectName') where project=$projectid";
$ret = insert_db($updateconfigfilesql);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$updateconfigfilesql\"\n");
	exit(1);
}
$updateconfigfilesql="update `script` set `testdata` = replace(`testdata`,'$original_projectname','$projectName') where project=$projectid";
$ret = insert_db($updateconfigfilesql);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$updateconfigfilesql\"\n");
	exit(1);
}
$updateconfigfilesql="update `script` set `configfile` = replace(`configfile`,'$original_projectname','$projectName') where project=$projectid";
$ret = insert_db($updateconfigfilesql);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$updateconfigfilesql\"\n");
	exit(1);
}

## check result 
if ($#selecttargetscriptresultid == $#selectoriginalscriptresultid) {
	print("Add " . $#selecttargetscriptresultid + 1 ." records into table[scriptfolder] successfully!\n");
} else {
	print("The scriptfolder number of copied is NOT equal the original number, Please check!\n");
}
##### end step3


### 4 update folder_script
$sql_cmd = "select * from `script` where project=$original_projectid";
    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }
    my $sth = $dbh->prepare($sql_cmd);
    $sth->execute;
    while(my @ary = $sth->fetchrow_array()){
	my $folder_scripttscriptid = $ary[0];
	my $getfolderidlist="select folderid from folder_script where scriptid=$folder_scripttscriptid";
	$ret = query_column_db($getfolderidlist);
	if ($ret->{ret} eq 'nok') {
		print("error to execute command \"$getfolderidlist\"\n");
		next;
	}
	my $folder_scriptfolderid = $ret->{value}->[0];
	my $scriptsql="select copyid from temp_script where originalid=$folder_scripttscriptid";
	$ret = query_column_db($scriptsql);
	if ($ret->{ret} eq 'nok') {
		print("error to execute command \"$scriptsql\"\n");
		exit(1);
	}
	my $targetscriptid = $ret->{value}->[0];
	my $foldersql="select copyid from temp_scriptfolder where originalid=$folder_scriptfolderid";
	$ret = query_column_db($foldersql);
	if ($ret->{ret} eq 'nok') {
		print("error to execute command \"$foldersql\"\n");
		exit(1);
	}
	my $targetfolderid = $ret->{value}->[0];
	my $insertsql="insert into `folder_script` values ($targetfolderid,$targetscriptid)";
	$ret = insert_db($insertsql);
	if ($ret->{ret} eq 'nok') {
		print("Error to execute command \"$insertsql\"\n");
		exit(1);
	}
    }
    $sth->finish();
    $dbh->disconnect();
### check 
my $folderscriptchecksql="select count(scriptid) as number from folder_script where scriptid in (select id from `script` where project=$projectid)";
$ret = query_column_db($folderscriptchecksql);
if ($ret->{ret} eq 'nok') {
	print("error to execute command \"$folderscriptchecksql\"\n");
	exit(1);
}
my $addednumber = $ret->{value}->[0];
my $folderscriptchecksql_1="select count(scriptid) as number from folder_script where scriptid in (select id from `script` where project=$original_projectid)";
$ret = query_column_db($folderscriptchecksql_1);
if ($ret->{ret} eq 'nok') {
	print("error to execute command \"$folderscriptchecksql_1\"\n");
	exit(1);
}
my $addednumber_1 = $ret->{value}->[0];
if ($addednumber == $addednumber_1) {
	print("Add $addednumber records into table[folder_script] successfully!\n");
} else {
	print("The folder_script number of copied is NOT equal the original number, Please check!\n");
}
#### end 4
#
###### 5 insert data into setfolder
$sql_cmd = "insert into `wats`.`setfolder` (name,parentid,productid,comments) values ('$projectName',0,$productid,'')";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
$sql_cmd = "delete from `wats`.`temp_setfolder` where originalid > 0";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
$sql_cmd = "select id from setfolder where name = '$original_projectname' and parentid=0";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
my $original_setfolderid = $ret->{value}->[0];
$sql_cmd = "select id from setfolder where name = '$projectName' and parentid=0";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
my $feedback3= $ret->{value}->[0];

my $inserttempsql="insert into temp_setfolder values ($original_setfolderid,'$original_projectname',$feedback3,'$projectName')";
my $ret1 = insert_db($inserttempsql);
if ($ret1->{ret} eq 'nok') {
	print("Error to execute command \"$inserttempsql\"\n");
	exit(1);
}

$sql_cmd = "select * from setfolder where FIND_IN_SET(id,getsetChildLst($original_setfolderid))";
    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }
    my $sth = $dbh->prepare($sql_cmd);
    $sth->execute;
    my $setfoldervalue = '';
    #$tmpscriptfoldervalue = '';
my @tmpsetfoldervalueid;
my @tmpsetfoldervaluename;
my $i = 0;
    while(my @ary = $sth->fetchrow_array()){
        #print join("\t",@ary),"\n";
	if ($i == 0) {
		$i++;
		next;
	}
	$setfoldervalue=$setfoldervalue."('$ary[1]',$feedback3,$ary[3],'$ary[4]'),";
	$tmpsetfoldervalueid[$i] = $ary[0];
	$tmpsetfoldervaluename[$i] = $ary[1]; 
	$i++;
    }
    $sth->finish();
    $dbh->disconnect();
$setfoldervalue =~ s/,$//;
$sql_cmd = "insert into setfolder(name,parentid,productid,comments) values $setfoldervalue";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}

### //add other data into the temp_setfolder
$sql_cmd = "select id from setfolder where id > $feedback3";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("error to execute command \"$sql_cmd\"\n");
	exit(1);
}
my $tmpsetfoldervalue = '';
my $result = $ret->{value};
for($i = 0; $i<= $#$result;$i++) {
	$tmpsetfoldervalue = $tmpsetfoldervalue . "($tmpsetfoldervalueid[$i+1],'$tmpsetfoldervaluename[$i+1]',$result->[$i],'$tmpsetfoldervaluename[$i+1]'),";
}
$tmpsetfoldervalue =~ s/,$//;

my $inserttempsql="insert into temp_setfolder values $tmpsetfoldervalue";
my $ret1 = insert_db($inserttempsql);
if ($ret1->{ret} eq 'nok') {
	print("Error to execute command \"$inserttempsql\"\n");
	exit(1);
}
for(my $i = 0; $i<= $#$result;$i++) {
	###update the parentid
	my $getidsql="select copyid from temp_setfolder where originalid in (select b.parentid from `setfolder` b inner join temp_setfolder c on b.id = c.originalid where c.copyid=".$result->[$i].")";
	$ret = query_column_db($getidsql);
	if ($ret->{ret} eq 'nok') {
		print("error to execute command \"$getidsql\"\n");
		exit(1);
	}
	my $parentid = $ret->{value}->[0];
	my $updateidsql="update setfolder set parentid=".$parentid." where parentid=$feedback3 and id =".$result->[$i]."";
	$ret = insert_db($updateidsql);
	if ($ret->{ret} eq 'nok') {
		print("Error to execute command \"$updateidsql\"\n");
		exit(1);
	}
}
## check result
$sql_cmd = "select count(id) as number from setfolder where FIND_IN_SET(id,getsetChildLst($feedback3))";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("error to execute command \"$sql_cmd\"\n");
	exit(1);
}
print("$ret->{value}->[0]\n");
$sql_cmd = "select count(id) as number from setfolder where FIND_IN_SET(id,getsetChildLst($original_setfolderid))";
$ret1 = query_column_db($sql_cmd);
if ($ret1->{ret} eq 'nok') {
	print("error to execute command \"$sql_cmd\"\n");
	exit(1);
}
print("$ret1->{value}->[0]\n");
if ($ret->{value}->[0] == $ret1->{value}->[0]) {
	print("Add $ret->{value}->[0] records into table[scriptfolder] successfully!\n");
} else {
	print("The scriptfolder number of copied is NOT equal the original number, Please check!\n");
}
#### end 5

### 6 insert data into set
my $insertsetsql="insert into `set` (name,author,date,productid,projectid,priority,topology,duration,comments,summary) select name,author,date,productid,$projectid,priority,topology,duration,comments,summary from `set` where projectid=$original_projectid";
my $ret1 = insert_db($insertsetsql);
if ($ret1->{ret} eq 'nok') {
	print("Error to execute command \"$insertsetsql\"\n");
	exit(1);
}
my $wats_prefix=$productName.'_set_';
my $updateidsql="update `set` set wats_set_id=concat('".$wats_prefix."',id) where projectid=$projectid";
$ret = insert_db($updateidsql);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}

$sql_cmd = "delete from `wats`.`temp_set` where originalid > 0";
$ret = insert_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$sql_cmd\"\n");
	exit(1);
}
my $selectoriginalsetsql="select id,name from `set` where projectid=$original_projectid";
    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }
    my $sth = $dbh->prepare($selectoriginalsetsql);
    $sth->execute;
my @tmpsetvalueid;
my @tmpsetvaluename;
my $i = 0;
    while(my @ary = $sth->fetchrow_array()){
	$tmpsetvalueid[$i] = $ary[0];
	$tmpsetvaluename[$i] = $ary[1]; 
	$i++;
    }
    $sth->finish();
    $dbh->disconnect();
$selectoriginalsetsql="select id,name from `set` where projectid=$projectid";
    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }
    my $sth = $dbh->prepare($selectoriginalsetsql);
    my $setdatastring = '';
    $sth->execute;
$i = 0;
    while(my @ary = $sth->fetchrow_array()){
	$setdatastring = $setdatastring ."($tmpsetvalueid[$i],'$tmpsetvaluename[$i]',$ary[0],'$ary[1]'),";
	$i++;
    }
    $sth->finish();
    $dbh->disconnect();
$setdatastring =~ s/,$//;
my $temp_setsql="insert into `temp_set` values $setdatastring";
$ret = insert_db($temp_setsql);
if ($ret->{ret} eq 'nok') {
	print("Error to execute command \"$temp_setsql\"\n");
	exit(1);
}

## check result
$sql_cmd = "select count(id) as number from `set` where projectid=$projectid";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("error to execute command \"$sql_cmd\"\n");
	exit(1);
}
print("$ret->{value}->[0]\n");
$sql_cmd = "select count(id) as number from `set` where projectid=$original_projectid";
my $ret1 = query_column_db($sql_cmd);
if ($ret1->{ret} eq 'nok') {
	print("error to execute command \"$sql_cmd\"\n");
	exit(1);
}
print("$ret->{value}->[0]\n");
print("$ret1->{value}->[0]\n");
if ($ret->{value}->[0] == $ret1->{value}->[0]) {
	print("Add $ret->{value}->[0] records into table[set] successfully!\n");
} else {
	print("The set number of copied is NOT equal the original number, Please check!\n");
}
### end 6

### 7 update folder_set
my $getfolder_setlist="select * from `set` where projectid=$original_projectid";
    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }
    my $sth = $dbh->prepare($getfolder_setlist);
    $sth->execute;
    while(my @ary = $sth->fetchrow_array()){
	my $folder_setsetid=$ary[0];
	my $getfolderidlist="select folderid from `folder_set` where setid=$folder_setsetid";
	$ret = query_column_db($getfolderidlist);
	if ($ret->{ret} eq 'nok') {
		print("error to execute command \"$getfolderidlist\"\n");
		exit(1);
	}
	my $folder_setfolderid = $ret->{value}->[0];
	my $setsql="select copyid from `temp_set` where originalid=$folder_setsetid";
	$ret = query_column_db($setsql);
	if ($ret->{ret} eq 'nok') {
		print("error to execute command \"$setsql\"\n");
		exit(1);
	}
	my $targetsetid = $ret->{value}->[0];
	my $foldersql="select copyid from `temp_setfolder` where originalid=$folder_setfolderid";
	$ret = query_column_db($foldersql);
	if ($ret->{ret} eq 'nok') {
		print("error to execute command \"$foldersql\"\n");
		exit(1);
	}
	my $targetfolderid = $ret->{value}->[0];
	my $insertsql="insert into `folder_set` values ($targetfolderid,$targetsetid)";
	$ret = insert_db($insertsql);
	if ($ret->{ret} eq 'nok') {
		print("Error to execute command \"$insertsql\"\n");
		exit(1);
	}
    }
    $sth->finish();
    $dbh->disconnect();
## check result
$sql_cmd = "select count(id) as number from `set` where projectid=$projectid";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("error to execute command \"$sql_cmd\"\n");
	exit(1);
}
print("$ret->{value}->[0]\n");
$sql_cmd = "select count(id) as number from `set` where projectid=$original_projectid";
my $ret1 = query_column_db($sql_cmd);
if ($ret1->{ret} eq 'nok') {
	print("error to execute command \"$sql_cmd\"\n");
	exit(1);
}
print("$ret->{value}->[0]\n");
print("$ret1->{value}->[0]\n");
if ($ret->{value}->[0] == $ret1->{value}->[0]) {
	print("Add $ret->{value}->[0] records into table[folder_set] successfully!!\n");
} else {
	print("The folder_set number of copied is NOT equal the original number, Please check!\n");
}
#### end 7
#
#### 8 update set_case
my $getsetlist="select * from `set_case` where setid in (select id from `set` where projectid=$original_projectid)";
    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }
    my $sth = $dbh->prepare($getsetlist);
    $sth->execute;
my $i = 0;
    while(my @ary = $sth->fetchrow_array()){
	my $originalsetid=$ary[0];
	my $setsql="select copyid from `temp_set` where originalid=$originalsetid";
	$ret = query_column_db($setsql);
	if ($ret->{ret} eq 'nok') {
		print("error to execute command \"$setsql\"\n");
		exit(1);
	}
	my $copysetid = $ret->{value}->[0];
	my $insertsql="insert into `set_case`(setid,caseid,sortorder) values ($copysetid,$ary[1],$ary[2])";
	$ret = insert_db($insertsql);
	if ($ret->{ret} eq 'nok') {
		print("Error to execute command \"$insertsql\"\n");
		exit(1);
	}
	$i++;
    }
    $sth->finish();
    $dbh->disconnect();
## check result
$sql_cmd = "select count(setid) as number from `set_case` where setid in (select id from `set` where projectid=$projectid)";
$ret = query_column_db($sql_cmd);
if ($ret->{ret} eq 'nok') {
	print("error to execute command \"$sql_cmd\"\n");
	exit(1);
}
print("$ret->{value}->[0]\n");
print("$i\n");
if ($ret->{value}->[0] == $i) {
	print("Add $ret->{value}->[0] records into table[set_case] successfully!!\n");
} else {
	print("The folder_set number of copied is NOT equal the original number, Please check!\n");
}
#### end 8



sub query_column_db {
    my $ret       = {};
    my @value     = ();
    my $query_cmd = shift();
    $ret->{ret} = 'nok';

    my $dbh ;

    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }
    my $sth = $dbh->prepare($query_cmd);

    $sth->execute;

    my $i = 0;
    while ( my $j = $sth->fetchrow_array() ) {
        $value[$i] = $j;
        $i = $i + 1;
    }
    $sth->finish();
    $dbh->disconnect();

    if ( scalar(@value) == 0 ) {
         print("error $query_cmd\n");
        $ret->{ret} = 'nok';
        return $ret;
    }

    $ret->{ret}   = 'ok';
    $ret->{value} = \@value;
    return $ret;
}

sub query_row_db {
    my $ret       = {};
    my @value     = ();
    my $query_cmd = shift();
    $ret->{ret} = 'nok';
    my $dbh ;

    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }


    my $sth = $dbh->prepare($query_cmd);

    $sth->execute;
    @value = $sth->fetchrow_array();

    $sth->finish();
    $dbh->disconnect();
    if ( scalar(@value) == 0 ) {
        print("error $query_cmd\n");
        $ret->{ret} = 'nok';
        return $ret;
    }

    $ret->{ret}   = 'ok';
    $ret->{value} = \@value;
    return $ret;
}

sub insert_db {
    my $ret        = {};
    my $insert_cmd = shift();

    # create database connection

    my $dbh ;
    #   print("info", "start to execute $insert_cmd", __FILE__, __LINE__);

    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd, { 'RaiseError' => 1 } );
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }

    if ( $dbh == 0 ) {

        $ret->{ret} = 'nok';
        return $ret;
    }
    print("------------------> insert_cmd:: $insert_cmd\n");
    $dbh->do($insert_cmd);

    $dbh->disconnect();
    $ret->{ret} = 'ok';
    return $ret;
}

sub update_db {
    my $query_cmd = shift();
    my $ret       = {};
    $ret->{ret}='nok';
    my $dbh ;
    eval{
        $dbh = DBI->connect( $db_host, $db_user, $db_passwd ) ;
    };

    if($@){
        print("error connect database error\n");
        $ret->{ret} = 'nok';
        return $ret;
    }

    eval{

        my $sth = $dbh->prepare($query_cmd);
    	print("------------------> update_cmd:: $query_cmd\n");
        $sth->execute;
        $dbh->disconnect();
    };

    if ($@) {
        print("error $query_cmd error\n");
        $ret->{ret} = 'nok';
        return $ret;
    } else {
        $ret->{ret} = 'ok';
        return $ret;
    }
}
