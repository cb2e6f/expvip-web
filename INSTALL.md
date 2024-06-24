# Install

Here I present my notes on installing expvip-web in an effort that at some 
future point how to install it doesn't have to be worked out from scratch. The 
context for this is that some current installs running on centos need 
migrating to a supported version of almalinux.

These instructions should be enough to get a working copy of expvip-web 
running on a fresh install of almalinux 9, some of these steps are not needed 
when installing to the VMs I have set up so I will try to note when this is 
the case.

There are some minor differences between the expvip variants, currently wheat, 
rust and bachberry, going forward these will be managed with branches. master 
being our main branch with master-wheat (will likely be just a copy of master 
for now), master-rust and master-bachberry holding the differences from 
master and rebasing on master for updates.

## update & enable repos

First we install any updates and enable some repos that we need.

> :note: **If running on one of our managed VMs**: This step is not needed 

    sudo dnf update -y
    sudo dnf config-manager --set-enabled crb
    sudo dnf install -y epel-release

## space

Our VMs require that space is allocated using LVM, here is and example of what 
that might look like:

    sudo lvextend -L +60G /dev/rootvg/var
    sudo xfs_growfs /dev/rootvg/var

Here we add ~60G to the volume mounted at /var as this is where our databases 
are stored it's likely where we will need the space.

## dependencies

Next we need to on stall our dependencies.

First is development tools:

    sudo dnf groupinstall -y "Development Tools"


### mysql

expvip uses mysql as it's main database backend so we install and enable this:

    sudo dnf install -y mysql mysql-server mysql-devel sqlite-devel
    sudo systemctl enable mysqld
    sudo systemctl start mysqld

### mongodb

expvip also uses mongodb for storing expression values. On a fresh install of 
almalinux we need to add the mongodb repo:

> :note: **If running on one of our managed VMs**: adding the repo is not needed as 
> it is already provided.

Create the file: /etc/yum.repos.d/mongodb.repo with the following content:

    [mongodb-org-6.0]
    name=MongoDB Repository
    baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/6.0/x86_64/
    gpgcheck=1
    enabled=1
    gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc

Then we can install and enable mongodb:

    sudo dnf install -y mongodb-org
    sudo systemctl start mongod
    sudo systemctl enable mongod

### node

For some javascript goodness we install node and yarn:

    sudo dnf module install -y nodejs:20
    sudo dnf install -y yarnpkg

### ruby dependencies

The follow can be needed for building ruby:

    sudo dnf install -y libyaml-devel
    sudo dnf install -y perl

### sequenceserver dependencies

We need the following for running sequenceserver:

    sudo dnf install -y libnsl

### nginx & passenger

For serving expvip we use nginx in conjunction with passenger, so we need to 
add the repo for passenger:

> :note: **If running on one of our managed VMs**: adding the repo is not needed as
> it is already provided.

    sudo curl --fail -sSLo /etc/yum.repos.d/passenger.repo https://oss-binaries.phusionpassenger.com/yum/definitions/el-passenger.repo

We can then install:

    sudo dnf module install -y nginx:1.24
    sudo dnf install -y nginx-mod-http-passenger

Now we need to configure nginx and passenger for our setup, first we need to 
add or change the following entries in: /etc/nginx/conf.d/passenger.conf to 
tell passenger where to find our ruby install:

    passenger_ruby /home/expvip/.rbenv/shims/ruby;
    passenger_temp_path /tmp/passenger_temp;

We then need to tell nginx to use passenger and where to find expvip, in:
/etc/nginx/nginx.conf we change the the ngnix user to expvip (which we will 
create shortly):

    <   user nginx;
    ---
    >   user expvip;

Then we set root to expvip-web's public directory and add the configuration 
for passenger: 

    <   root /usr/share/nginx/html;
    ---
    >   root /home/expvip/expvip-web/public;
    >
    > 	passenger_enabled on;
    > 	passenger_app_env development;

We can then start and enable nginx:

    sudo systemctl start nginx.service
    sudo systemctl enable nginx.service

### firewall

We need to change our firewall settings to allow access to our webserver with:

    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --list-all
    sudo firewall-cmd --reload

### selinux

On systems where selinux is enabled some thing like the following may be of 
use for allowing permissions for expvip:

    sudo audit2allow -a
    sudo audit2allow -a -M expvip
    sudo semodule -i expvip.pp

## expvip user

We add a user to the system to run things as:

    sudo useradd expvip

Unless specified otherwise this is the user for running any following commands.

## install ruby

Now as our expvip user we can install rbenv & ruby-build and to manage our 
ruby versions.

    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
    rbenv install 2.7.8
    rbenv global 2.7.8

## expvip

Get and checkout the relevant branch of expvip-web:

    git clone https://github.com/cb2e6f/expvip-web.git
    cd expvip-web/
    git checkout <branch we want to run>

Install our ruby gem dependencies:

    gem install bundler:1.17.3
    bundle install

Install our javascript dependencies:
> :note: whilst yarn is mentioned for this purpose elsewhere, it turns out 
> because of the differences in how they handle dependencies a working install 
> can currently only be achieved by using npm.

    npm install
    npm run bundle

[comment]: # (
## kallisto
)
[comment]: # (
Only needed for import so should really be handled by someting else.
)
[comment]: # (
    mkdir dl
    mkdir ~/bin
    cd dl
    curl -L -O https://github.com/pachterlab/kallisto/releases/download/v0.50.1/kallisto_linux-v0.50.1.tar.gz
    tar -xzf kallisto_linux-v0.50.1.tar.gz
    cd kallisto
    cp kallisto ~/bin/
)

## sequenceserver

expvip contains and instance of sequence server as such we need to install 
blast and setup a config file for this to use. 

    mkdir ~/.sequenceserver
    cd ~/.sequenceserver
    wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.2.30/ncbi-blast-2.2.30+-x64-linux.tar.gz
    tar -xf ncbi-blast-2.2.30+-x64-linux.tar.gz
    
We also need to create a config file: ~/.sequenceserver.conf with the following content:

    ---
    :host: 0.0.0.0
    :port: 4567
    :databases_widget: classic
    :options:
    :blastn:
    - "-task blastn"
    - "-evalue 1e-5"
      :blastp:
    - "-evalue 1e-5"
      :blastx:
    - "-evalue 1e-5"
      :tblastx:
    - "-evalue 1e-5"
      :tblastn:
    - "-evalue 1e-5"
      :num_threads: 1
      :num_jobs: 1
      :job_lifetime: 43200
      :bin: "/home/expvip/.sequenceserver/ncbi-blast-2.2.30+/bin"
      :database_dir: "/var/data"

For the install that I have been looking at I have put sequenceserver's genome 
data in /var/data (as that is where I had space) this directory also need to 
be accessible to our expvip user.


## data

### sequenceserver

Sequence data for sequence server needs placing in it's database_dir, in my 
case /var/data e.g.

    [goz24vof@v1329 ~]$ ls /var/data/
    Nicola_Love_JIC.NL.ENQ-1131.01_LIB19133_to_LIB19141.fa
    Nicola_Love_JIC.NL.ENQ-1131.01_LIB19133_to_LIB19141.fa.nhd
    Nicola_Love_JIC.NL.ENQ-1131.01_LIB19133_to_LIB19141.fa.nhi
    Nicola_Love_JIC.NL.ENQ-1131.01_LIB19133_to_LIB19141.fa.nhr
    Nicola_Love_JIC.NL.ENQ-1131.01_LIB19133_to_LIB19141.fa.nin
    Nicola_Love_JIC.NL.ENQ-1131.01_LIB19133_to_LIB19141.fa.nog
    Nicola_Love_JIC.NL.ENQ-1131.01_LIB19133_to_LIB19141.fa.nsd
    Nicola_Love_JIC.NL.ENQ-1131.01_LIB19133_to_LIB19141.fa.nsi
    Nicola_Love_JIC.NL.ENQ-1131.01_LIB19133_to_LIB19141.fa.nsq
    TCS_Philippe_Vain_JIC_NL_ENQ-1131_02_LIB19419_to_LIB19427.fa
    TCS_Philippe_Vain_JIC_NL_ENQ-1131_02_LIB19419_to_LIB19427.fa.nhd
    TCS_Philippe_Vain_JIC_NL_ENQ-1131_02_LIB19419_to_LIB19427.fa.nhi
    TCS_Philippe_Vain_JIC_NL_ENQ-1131_02_LIB19419_to_LIB19427.fa.nhr
    TCS_Philippe_Vain_JIC_NL_ENQ-1131_02_LIB19419_to_LIB19427.fa.nin
    TCS_Philippe_Vain_JIC_NL_ENQ-1131_02_LIB19419_to_LIB19427.fa.nog
    TCS_Philippe_Vain_JIC_NL_ENQ-1131_02_LIB19419_to_LIB19427.fa.nsd
    TCS_Philippe_Vain_JIC_NL_ENQ-1131_02_LIB19419_to_LIB19427.fa.nsi
    TCS_Philippe_Vain_JIC_NL_ENQ-1131_02_LIB19419_to_LIB19427.fa.nsq

### assets

Variants of expvip (e.g. wheat, rust, bachberry) require some differing assets,
as such these need copying in to place e.g.

    Untracked files:
     (use "git add <file>..." to include in what will be committed)
    	public/data/
    	public/images/berry.png

    no changes added to commit (use "git add" and/or "git commit -a")
    [expvip@v1329 expvip-web]$ ls public/data/
    default_metadata.txt  Rgenevieri_fasta        Ridaeus_fasta
    FactorOrder.tsv       Rgenevieri_kalisto.zip  Ridaeus_kalisto.zip
    [expvip@v1329 expvip-web]$ ls public/images/
    0416PPCover.png  0817Cover.png  4.cover-source.jpg  8a0011352217f37fe9b99b31d68f1f33.gif  berry.png

Going forward we need to come up with a better method for managing these 
files as they can be large binary files not suited to storage in git.

### expvip

One should now be able to load appropriate expression and meta data with 
something akin to the following:

Set up our database:

    rails db:create
    rails db:setup
    rails db:migrate

Load our data:

    rails load_data:default_factor_order[/home/expvip/default_factor_order.txt]
    rails load_data:factor[/home/expvip/IWGSC1/FactorOrder.tsv]
    rails load_data:metadata[/home/expvip/IWGSC1/default_metadata.txt]
    rails load_data:ensembl_genes[IWGSC1,/home/expvip/IWGSC1/Triticum_aestivum.IWGSC2.26.cdna.all.fa]
    rails load_data:homology_pairs[IWGSC1,/home/expvip/IWGSC1/compara_homolgy.txt]
    rails load_data:values_mongo[first,IWGSC1,tpm,/home/expvip/IWGSC1/final_output_tpm.txt]
    rails load_data:values_mongo[first,IWGSC1,count,/home/expvip/IWGSC1/final_output_counts.txt]

For our VM installs data was however dumped from the old VMs and restored to the new ones.