#declare calling params 
param( [string] $dir) 

dir $dir | Unblock-file
