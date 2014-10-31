capi5k-puppetcluster
====================

This capi5k allows you to bootstrap your puppet master/clients cluster.


### Add it in bower.json

``` json
"dependencies":
  {
    "capi5k-puppetcluster" : "https://github.com/capi5k/capi5k-puppetcluster/tarball/master"
  },
```

Then run ```xpm install```. Specific tasks should now be available in your capistrano environment.


### Tasks

```
cap puppetcluster               # Install a puppet cluster
cap puppetcluster:clients       # Install the clients
cap puppetcluster:clients:certs # Certificate request
cap puppetcluster:master        # Install the puppet master
cap puppetcluster:passenger     # Add passenger support for the puppet master
cap puppetcluster:sign_all      # Sign all pending certificates
````

### Passenger support

Once the puppetcluster is set and certificates are signed, you can install passenger using 

```
cap passenger
```

### Troubeshootings

You may need to call twice the ```puppetcluster```tasks :

```
cap puppetcluster; cap puppetcluster [passenger]
```
