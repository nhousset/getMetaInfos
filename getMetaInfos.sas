/************************************************************
	Author  Nicolas Housset
    16 Mars 2017
************************************************************/

	

%macro getMetaInfos(EXCELFILE,OUTPUTFORMAT);
	data metadata_libraries;
  length uri serveruri conn_uri domainuri libname ServerContext AuthDomain path_schema
         usingpkguri type tableuri coluri $256 id $17
         desc $200 libref engine $8 isDBMS $1 DomainLogin  $32;
  keep libname desc libref engine ServerContext path_schema AuthDomain table colname
      coltype collen IsPreassigned IsDBMSLibname id;
  nobj=.;
  n=1;
  uri='';
  serveruri='';
  conn_uri='';
  domainuri='';

         /***Determine how many libraries there are***/
  nobj=metadata_getnobj("omsobj:SASLibrary?@Id contains '.'",n,uri);
         /***Retrieve the attributes for all libraries, if there are any***/
  if n>0 then do n=1 to nobj;
    libname='';
    ServerContext='';
    AuthDomain='';
    desc='';
    libref='';
    engine='';
    isDBMS='';
    IsPreassigned='';
    IsDBMSLibname='';
    path_schema='';
    usingpkguri='';
    type='';
    id='';
    nobj=metadata_getnobj("omsobj:SASLibrary?@Id contains '.'",n,uri);
    rc= metadata_getattr(uri, "Name", libname);
    rc= metadata_getattr(uri, "Desc", desc);
    rc= metadata_getattr(uri, "Libref", libref);
    rc= metadata_getattr(uri, "Engine", engine);
    rc= metadata_getattr(uri, "IsDBMSLibname", isDBMS);
    rc= metadata_getattr(uri, "IsDBMSLibname", IsDBMSLibname); 
    rc= metadata_getattr(uri, "IsPreassigned", IsPreassigned); 
    rc= metadata_getattr(uri, "Id", Id);

    /*** Get associated ServerContext ***/
    i=1;
    rc= metadata_getnasn(uri, "DeployedComponents", i, serveruri);
    if rc > 0 then rc2= metadata_getattr(serveruri, "Name", ServerContext);
    else ServerContext='';

    /*** If the library is a DBMS library, get the Authentication Domain
         associated with the DBMS connection credentials ***/
    if isDBMS="1" then do;
      i=1; 
      rc= metadata_getnasn(uri, "LibraryConnection", i, conn_uri);
      if rc > 0 then do;
        rc2= metadata_getnasn(conn_uri, "Domain", i, domainuri);
		

        if rc2 > 0 then rc3= metadata_getattr(domainuri, "Name", AuthDomain);
      end;
    end;

    /*** Get the path/database schema for this library ***/
    rc=metadata_getnasn(uri, "UsingPackages", 1, usingpkguri);
    if rc>0 then do;
      rc=metadata_resolve(usingpkguri,type,id);  
      if type='Directory' then 
        rc=metadata_getattr(usingpkguri, "DirectoryName", path_schema);
      else if type='DatabaseSchema' then 
        rc=metadata_getattr(usingpkguri, "Name", path_schema);
      else path_schema="unknown";
    end;

  output;
    
  end;
 
 run;

	data work.Libraries;
		length  LibId LibName $ 32 LibRef LibEngine $ 8 LibPath $ 256 ServerContext uri uri2 type $ 256 server $ 32  ;
		label
			LibId = "ID"
			LibName = "Nom"
			LibRef = "Libref"
			LibEngine = "Moteur"
			ServerContext = "Serveur"
			LibPath = "Path";

		call missing(LibId,LibName,LibRef,LibEngine,LibPath,ServerContext,uri,uri2,type,server);
		n=1;
		n2=1;

		rc=metadata_getnobj("omsobj:SASLibrary?@Id contains '.'",n,uri);
		if rc<=0 then put "NOTE: rc=" rc 
			"There are no Libraries defined in this repository"
			" or there was an error reading the repository.";

		do while(rc>0);
			objrc=metadata_getattr(uri,"Id",LibId);
			objrc=metadata_getattr(uri,"Name",LibName);
			objrc=metadata_getattr(uri,"Libref",LibRef);
			objrc=metadata_getattr(uri,"Engine",LibEngine);
			objrc=metadata_getnasn(uri,"DeployedComponents",n2,uri2);
			if objrc<=0 then
			do;
				put "NOTE: There is no DeployedComponents association for "
				LibName +(-1)", and therefore no server context.";
				ServerContext="";
			end;

			do while(objrc>0);
				objrc=metadata_getattr(uri2,"Name",server);
				if n2=1 then ServerContext=quote(trim(server));
				else ServerContext=trim(ServerContext)||" "||quote(trim(server));
					n2+1;
					objrc=metadata_getnasn(uri,"DeployedComponents",n2,uri2);
			end; 
			n2=1;
			objrc=metadata_getnasn(uri,"UsingPackages",n2,uri2);
			if objrc<=0 then
			do;
				put "NOTE: There is no UsingPackages association for " 
				LibName +(-1)", and therefore no Path.";
				LibPath="";
			end;

			do while(objrc>0);
				objrc=metadata_resolve(uri2,type,id);
				if type='Directory' then objrc=metadata_getattr(uri2,"DirectoryName",LibPath);
					else if type='DatabaseSchema' then objrc=metadata_getattr(uri2, "Name", LibPath);
					else LibPath="*unknown*";
					output;
					LibPath="";
					n2+1;
					objrc=metadata_getnasn(uri,"UsingPackages",n2,uri2);
			end; 
			ServerContext="";
			n+1;
			n2=1;
			rc=metadata_getnobj("omsobj:SASLibrary?@Id contains '.'",n,uri);
		end;
			
		keep
			LibName
			LibRef
			LibEngine
			ServerContext
			LibPath
			LibId; 
run;


data logins;

  
  length LoginObjId UserId IdentId AuthDomId $ 17
         IdentType $ 32
         Name DispName Desc uri uri2 uri3 AuthDomName $ 256;

  call missing
(LoginObjId, UserId, IdentType, IdentId, Name, DispName, Desc, AuthDomId, AuthDomName);
  call missing(uri, uri2, uri3);
  n=1;


  objrc=metadata_getnobj("omsobj:Login?@Id contains '.'",n,uri);
  if objrc<=0 then put "NOTE: rc=" objrc 
    "There are no Logins defined in this repository"
    " or there was an error reading the repository.";

  do while(objrc>0);
     arc=metadata_getattr(uri,"Id",LoginObjId);
     arc=metadata_getattr(uri,"UserId",UserId);
  


     n2=1;
     asnrc=metadata_getnasn(uri,"AssociatedIdentity",n2,uri2);
     if asnrc<=0 then put "NOTE: rc=" asnrc 
       "There is no Person or Group associated with the " UserId "user ID.";



     else do;
       arc=metadata_resolve(uri2,IdentType,IdentId);



       arc=metadata_getattr(uri2,"Name",Name);
       arc=metadata_getattr(uri2,"DisplayName",DispName);
       arc=metadata_getattr(uri2,"Desc",Desc);
     end;
  
  
     n3=1;
     autrc=metadata_getnasn(uri,"Domain",n3,uri3);
     if autrc<=0 then put "NOTE: rc=" autrc 
       "There is no Authentication Domain associated with the " UserId "user ID.";
 

     else do;
       arc=metadata_getattr(uri3,"Id",AuthDomId);
       arc=metadata_getattr(uri3,"Name",AuthDomName);
	   
     end;

     output;


  call missing(LoginObjId, UserId, IdentType, IdentId, Name, DispName, Desc, AuthDomId, 
AuthDomName);

 n+1;
  objrc=metadata_getnobj("omsobj:Login?@Id contains '.'",n,uri);
  end;  



  keep LoginObjId UserId IdentType Name DispName Desc AuthDomId AuthDomName; 
run;


data users_grps;
   length uri name group groupuri $256 id $20;
  
       /* Initialize variables to missing. */
   n=1;
   uri='';
   name='';
   group='';
   groupuri='';
   id='';
  
       /* Determine how many person objects are defined. */
   nobj=metadata_getnobj("omsobj:Person?@Id contains '.'",n,uri);
   if nobj=0 then put 'No Persons available.';

   else do while (nobj > 0);

         /* Retrieve the current person's name. */
      rc=metadata_getattr(uri, "Name", Name);

	 /* Get the group association information for the current person. */
      a=1;
      grpassn=metadata_getnasn(uri,"IdentityGroups",a,groupuri);
      
         /* If this person does not belong to any groups, set their group */
         /* variable to 'No groups' and output the name. */
      if grpassn in (-3,-4) then do;
         group="No groups";
         output;
      end;

         /* If the person belongs to any groups, loop through the list */
         /* and retrieve the name of each group, outputting each on a */
         /* separate record. */
      else do while (grpassn > 0);
         rc2=metadata_getattr(groupuri, "Name", group);
         a+1;
         output;
         grpassn=metadata_getnasn(uri,"IdentityGroups",a,groupuri);
      end;
	   
         /* Retrieve the next person's information. */
      n+1;
      nobj=metadata_getnobj("omsobj:Person?@Id contains '.'",n,uri);
   end;
  keep name group;
run;

   /* Display the list of users and their groups. */
proc report data=users_grps nowd headline headskip;
   columns name group;
   define name / order 'User Name' format=$30.;
   define group / order 'Group' format=$30.;
   break after name / skip;
run;


data work.Identities;

length IdentId IdentName DispName ExtLogin IntLogin DomainName $32 
uri uri2 uri3 uri4 $256;


label
	IdentId    = "Identity Id"
	IdentName  = "Identity Name"
	DispName   = "Display Name"
	ExtLogin   = "External Login"
	IntLogin   = "Is Account Internal?"
	DomainName = "Authentication Domain";


call missing(IdentId, IdentName, DispName, ExtLogin, IntLogin, DomainName, 
uri, uri2, uri3, uri4);
n=1;
n2=1;


rc=metadata_getnobj("omsobj:Person?@Id contains '.'",n,uri);
if rc<=0 then put "NOTE: rc=" rc
"There are no identities defined in this repository" 
" or there was an error reading the repository.";


do while(rc>0); 
	objrc=metadata_getattr(uri,"Id",IdentId);
	objrc=metadata_getattr(uri,"Name",IdentName); 
	objrc=metadata_getattr(uri,"DisplayName",DispName);


objrc=metadata_getnasn(uri,"InternalLoginInfo",n2,uri2);


IntLogin="Yes";
DomainName="**None**";
if objrc<=0 then
do;
put "NOTE: There are no internal Logins defined for " IdentName +(-1)".";
IntLogin="No";
end;


objrc=metadata_getnasn(uri,"Logins",n2,uri3);


if objrc<=0 then
do;
put "NOTE: There are no external Logins defined for " IdentName +(-1)".";
ExtLogin="**None**";
output;
end;


do while(objrc>0);
objrc=metadata_getattr(uri3,"UserID",ExtLogin);

DomainName="**None**";
objrc2=metadata_getnasn(uri3,"Domain",1,uri4);
if objrc2 >0 then
do;
 objrc2=metadata_getattr(uri4,"Name",DomainName);
end;

/*Output the record. */
output;

n2+1;


objrc=metadata_getnasn(uri,"Logins",n2,uri3);
end; 


n+1;
n2=1;

rc=metadata_getnobj("omsobj:Person?@Id contains '.'",n,uri);
end; 

keep IdentId IdentName DispName ExtLogin IntLogin DomainName; 
run;



PROC EXPORT DATA=metadata_libraries outfile=&EXCELFILE dbms=&OUTPUTFORMAT  label  replace;
sheet="Bibliothèques I"; 
run;
PROC EXPORT DATA=Libraries outfile=&EXCELFILE dbms=&OUTPUTFORMAT label  replace;
sheet="Bibliothèques II";
run;
PROC EXPORT DATA=Identities outfile=&EXCELFILE dbms=&OUTPUTFORMAT label  replace;
sheet="Identities";
run;
PROC EXPORT DATA=logins outfile=&EXCELFILE dbms=&OUTPUTFORMAT label  replace;
sheet="logins";
run;
PROC EXPORT DATA=users_grps outfile=&EXCELFILE dbms=&OUTPUTFORMAT label  replace;
sheet="Utilisateurs et groupes";
run;



%mend getMetaInfos;