# Web Application Installation

The Web User Interface is built on [NodeJS](https://nodejs.org/) using the framework [SailsJS](http://sailsjs.org/) on the server side and [AngularJS](https://angular.io/) on the client side. It is connected to [PostgreSQL](https://www.postgresql.org/) for managing the data and to [Redis](http://redis.io/) for managing sessions.

The versions are:

 - NodeJS: 4.4.1
 - PostgreSQL: 9.5

 - For the frameworks and other libraries, check the files `package.json` and `bower.json`

## Structure

The folder is called 	`web` and its structure is the following:
```
web
├── client
│   ├── css
│   │   └── styles.css
│   ├── index.html
│   ├── js
│   │   ├── app.js
│   │   ├── controllers
│   │   │   └── home.js
│   │   └── directives.js
│   ├── README.md
│   ├── templates
│   │   ├── about.html
│   │   └── home.html
│   └── vendor
│       └── mendeley
│           ├── standalone.min.js
│           └── standalone.min.js.map
├── common
    |   ...
├── config.json
├── datasources.json
├── jsconfig.json
├── model-config.json
├── node_modules
    |   ...
├── nodemon.json
├── package.json
├── README.md
└── server
    ├── boot
    │   ├── authentication.js
    │   └── routes.js
    ├── component-config.json
    ├── config.json
    ├── datasources.json
    ├── datasources.local.js
    ├── middleware.json
    ├── middleware.production.json
    ├── model-config.json
    └── server.js
```

Some comments about the structure:

 - The `.tmp` folder contains the public files, which are automatically generated from a Grunt task of Sails.
 - The `api` folder is the server side logic, which contains the controllers, models and services.
 - The `assets` folder is the client side logic.
	 - The `bower` folder contains the third-party libraries, which are automatically copied from `bower_sources` using a Grunt task.
	 - Mainly Angular code resides inside the `js` folder
		 - The `app.js` file contains the definition of the angular module and some configurations. At the end of the file, there are some parameters that can be modified, for example, the initial latitude and longitude, the original language, the available languages, the options for the markers clusters, etc.
		 - The directives are in the file `directives.js`, the controllers are inside the folder `controllers` and the services inside the folder `services`.
	 - The templates are unified into a single file, as well as the js and css scripts (only in production)
 - About the `config` folder, here are listed the files that were modified
 - In the `tasks` folder there are the Grunt tasks. Some of them were modified to customize the development.
 - The `tests` folder contains the tests for the application, but they are still under develpment.



## Deployment

### Install PostgreSQL

Please follow the instructions for installing the RDBMS system PostgreSQL 9.5 located [here](db.md).


### Install Redis

Install Redis and start the service.

 - On Centos, follow this [guide](http://sharadchhetri.com/2014/10/04/install-redis-server-centos-7-rhel-7/)
	 - `yum install wget`
	 - `wget -r --no-parent -A 'epel-release-*.rpm' http://dl.fedoraproject.org/pub/epel/7/x86_64/e/`
	 - `rpm -Uvh dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-*.rpm`
	 - `yum install redis`
	 - `systemctl start redis.service`
	 - `systemctl enable redis.service`

 - On Ubuntu
	 - `sudo apt-get install redis-server`
	 - `sudo service redis-server`

### Install NodeJS

Install NodeJS downloading from its [site](https://nodejs.org/en/download/) or:

 - On Ubuntu
	 - `curl -sL https://deb.nodesource.com/setup_4.x | sudo -E bash -`
	 - `sudo apt-get install -y nodejs`


Install SailsJS

 - `sudo npm -g install sails`

Install Bower

 - `sudo npm -g install bower`

Install PM2

 - `sudo npm -g install pm2`


### Initialize the application

 - Clone (or update if this was already done) the github repository https://github.com/DMKM1517/author_disambiguation
 - On this directory create the file `db_login.json` with the content:
```
{
  "dbname": "ArticlesDB",
  "host" : "<host>",
  "port" : 5432,
  "user" : "dmkm",
  "password" : "<password>"
}
```

 - Install the dependencies for the web
	 - `cd web`
	 - `npm install --prod`
	 - `bower install`
 - Run the server using PM2
	 - `pm2 start app.js --name web -x -- --prod`
 - Save the process to startup
	 - `pm2 startup`
	 - (copy and execute the output line)
	 - `pm2 save`
 - The default port is `1337`. To change it, modify the file `config/env/production.js` and uncomment or update the property `port: 80`


### Update the application

 - On the github directory
	 - `git pull`
	 - (make any modifications if needed)
 - Restart the server
	`pm2 restart web`
	 - Check the logs
		`pm2 logs web`
