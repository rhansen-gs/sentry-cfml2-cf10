# Sentry Client for ColdFusion

This CFC is a slight modification of the sentry-cfml2 client by KrunchMuffin (https://github.com/KrunchMuffin/sentry-cfml2)
sentry-cfml2 is based on the fork sentry-cfml client developed 
by GiancarloGomez (https://github.com/GiancarloGomez/sentry-cfml)
which it was based off of the original raven-cfml client 
developed by jmacul2 (https://github.com/jmacul2/raven-cfml)

This code has been modified to run under ColdFusion 10.
Testing on later versions of ColdFusion and Lucee has not been done.

Sentry SDK Documentation
https://docs.sentry.io/clientdev/

## Installation
To install simply clone or download the sentry.cfc and customJsonSerializer.cfc file and place it anywhere in your
project. By default both files should be placed in the same directory.

## Instantiating as a Singleton
sentry-cfml2 can be instantiated each time you call it or it can
also live as a Singleton in your Application scope.

```javascript
function onApplicationStart(){

    application.sentry = new path.to.sentry(
        release     : "release-number-of-your-application",
        environment : "production|staging|etc",
        publicKey   : "your-public-key",
        privateKey  : "your-private-key",
        projectID   : "your-project-id"
    );

    return true;
}
```

## Using in your Application
Add to the onError() function to use for application wide errors.
 ```javascript
function onError(
    exception,
    eventName
){
    application.sentry.captureException(
        exception : arguments.exception
    );
}
```

## Usage
It is recommended that you review the [Sentry SDK Docs](https://docs.sentry.io/clientdev/attributes/) to understand the attributes and Interfaces that are supported.

## Examples
The following are examples on how to send messages and errors to Sentry. The examples are based on the singleton instance.

### Passing Messages
An information Message using a thread to post to Sentry
including data that is passed into the [User Interface](https://docs.sentry.io/clientdev/interfaces/user/)
```javascript

    application.sentry.captureMessage(
        message     : "This is just info",
        level       : "info",
        useThread   : true,
        userInfo    : {
            id          : 100,
            email       : "john.doe@test.com",
            type        : "administrator",
            username    : "john",
            ip_address  : cgi.remote_addr
        }
    );

```

Other level types allowed by Sentry
```javascript

    application.sentry.captureMessage(
        message :"This is a fatal message",
        level   :"fatal"
    );

    application.sentry.captureMessage(
        message :"This is an error message",
        level   :"error"
    );

    application.sentry.captureMessage(
        message :"This is a warning message",
        level   :"warning"
    );


    application.sentry.captureMessage(
        message :"This is a debug message",
        level   :"debug"
    );

```

### Capturing Errors
To capture an error you simply use the ``captureExeption`` function. Capturing an exception allows
for more options than just posting a message. Review the argument hints on the CFC for more information.
```javascript

    application.sentry.captureException(
        exception                   : e,
        level                       : "error",
        oneLineStackTrace           : true,
        showJavaStackTrace          : true,
        removeTabsOnJavaStackTrace  : false,
        additionalData              : {
            session : session
        },
        useThread                   : true,
        userInfo                    : {}
    );

```


