Install git 
Clone script 
give permission ``chmod +x install_basic.sh```

run script 
 this will install basic required packages 

 to enable WAL Archiving , run the script WAL-Enable.sh 

this will enable wal archiviing and initialize the repository for backup 



Authorize ``` gcloud auth login ```

gcloud projects list  and gcloud config set project Project_id 

 gsutil ls to list appropriate s3 bucket 

 
gcsfuse psql-002 /var/lib/pgbackrest     psql-002 as storage name to mount to Default Directory 


 
