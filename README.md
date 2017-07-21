## Local minikube development tools

### Overview

This project is a collection of tools targetting local container development using a [Minikube](https://github.com/kubernetes/minikube/releases). The intent is to let you run a local trimmed down 
version of what is being deployed to integration/staging/production.

A few standard tools are required beyond the minikube setup itself:

 * [jq](https://stedolan.github.io/jq/)
 * [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

### Exposing services

A common workflow is to run a few things in your local minikube and develop your code against them.
The *service-env.sh* script will modify your environment to route traffic to any valid *service* running
in the minikube. Each named port defined on a service will be exposed as a environment variable whose name is a concatenation of the service and port identifiers. Its value will be the usual IP address / TCP port combination.

The attached *local.yml* sample will setup a trivial environment made of a single pod running a HTTP server
and a service called *test* exposing it on TCP 80. Go ahead and setup both the minikube and this
manifest:

```
$ cd ads-infra-localdev
$ minikube start
$ kubectl create -f local.yaml
```

You are ready to now tweak your minikube to expose and access its services by sourcing *service-env.sh*:

```
$ ./service-env.sh setup
Setting up KUBERNETES_HTTPS - 10.0.2.15:443
Setting up TEST_HTTP - 172.17.0.3:80
```

At this point the service *test* exposing a port called *http* is exposed as $TEST_HTTP. This IP address
will be routed to the proxy running in the minikube VM. Let's try to reach it:

```
$ curl $TEST_HTTP
OK
```

You can at any moment refresh the variables, typically if you deploy or modify your services by using the
*sync* command. Once you are done make sure to undo the tweaks by sourcing with the *teardown* command.

### Caveats

 Please make sure to first source with the *teardown* command before scrapping the minikube.
 
 This will work best if we $ minikube start --extra-config=apiserver.ServiceNodePortRange=1000-40000

### Support

Contact samir@unity3d.com for more information about this project.
