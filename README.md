## react-native-oauth

The `react-native-oauth` library provides an interface to OAuth 1.0 and OAuth 2.0 providers, such as [Twitter](http://twitter.com) and [Facebook](http://facebook.com) to React native.

## TL;DR;

This library cuts out the muck of dealing with the [OAuth 1.0](https://tools.ietf.org/html/rfc5849) and [OAuth 2.0](http://oauth.net/2/) protocols in react-native apps. The API is incredibly simple and straight-forward and is intended on getting you up and running quickly with OAuth providers (such as Facebook, Github, Twitter, etc).

```javascript
const authManager = new OAuthManager()
authManager.configureProvider("twitter", {
  consumer_key: 'SOME_CONSUMER_KEY',
  consumer_secret: 'SOME_CONSUMER_SECRET'
});

// ...
const appUrl = 'app-uri://oauth-callback/twitter'
authManager.authorizeWithCallbackURL('twitter', appUrl)
.then((resp) => {
  // We have a user with user credentials
  authManager.makeRequest('twitter', 'get', 'https://api.twitter.com/1.1/statuses/mentions_timeline.json')
    .then((stringResponse) => {
      console.log('RESPONSE as a string: ', stringResponse);
    })
    .catch((err) => {
      console.log('Error making request', err);
    })
})
```

## Features

* Isolates the OAuth experience to a few simple methods.
* Stores OAuth token credentials away for safe-keeping (using React Native's [AsyncStorage](https://facebook.github.io/react-native/docs/asyncstorage.html)) so you don't have to deal with it at all.
* Works with many providers and relatively simple to add a provider

## Installation

Install `react-native-oauth` in the usual manner using `npm`:

```javascript
npm install --save react-native-oauth
```

As we are integrating with react-native, we have a little more setup to integrating with our apps.

### iOS setup

#### Automatically with [rnpm](https://github.com/rnpm/rnpm)

To automatically link our `react-native-oauth` client to our application, use the `rnpm` tool. [rnpm](https://github.com/rnpm/rnpm) is a React Native package manager which can help to automate the process of linking package environments.

```bash
rnpm link
```

#### Manually

If you prefer not to use `rnpm`, we can manually link the package together with the following steps, after `npm install`:

1. In XCode, right click on `Libraries` and find the `Add Files to [project name]`.

![Add library to project](http://d.pr/i/2gEH.png)

2. Add the `node_modules/react-native-oauth/ios/OAuthManager.xcodeproj`

![OAuthManager.xcodeproj in Libraries listing](http://d.pr/i/19ktP.png)

3. In the project's "Build Settings" tab in your app's target, add `libOAuthManager.a` to the list of `Link Binary with Libraries`

![Linking binaries](http://d.pr/i/1cHgs.png)

4. Ensure that the `Build Settings` of the `OAuthManager.xcodeproj` project is ticked to _All_ and it's `Header Search Paths` include both of the following paths _and_ are set to _recursive_:

  1. `$(SRCROOT)/../../react-native/React`
  2. `$(SRCROOT)/../node_modules/react-native/React`

![Recursive paths](http://d.pr/i/1hAr1.png)

### Android setup

Coming soon (looking for contributors).

## Handle deep linking loading

**Required step**

We'll need to handle app loading from a url with our app in order to handle authentication from other providers. That is, we'll need to make sure our app knows about the credentials we're authenticating our users against when the app loads _after_ a provider is authenticated against.

### iOS setup

We need to add a callback method in our `ios/AppDelegate.m` file and then call our OAuthManager helper method. Let's load the `ios/AppDelegate.m` file and add the following all the way at the bottom (but before the `@end`):

```objectivec
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
  return [OAuthManager handleOpenUrl:application openURL:url sourceApplication:sourceApplication annotation:annotation];
}
```

When our app loads up with a request that is coming back from OAuthManager _and_ matches the pattern of `[app-name]://oauth-callback/{providerName}`, the OAuthManager will take over and handle the rest and storing the credentials for later use.

## Configuring our providers

Providers, such as Facebook require some custom setup for each one. The following providers have been implemented and we're working on making more (and making it easier to add more, although the code is not impressively complex either, so it should be relatively simple to add more providers).

In order to configure providers, the `react-native-oauth` library exports the `configureProvider()` method, which accepts _two_ parameters and returns a promise:

1. The provider name, such as `twitter` and `facebook`
2. The provider's individual credentials

For instance, this might look like:

```javascript
const config =  {
  twitter: {
    consumer_key: 'SOME_CONSUMER_KEY',
    consumer_secret: 'SOME_CONSUMER_SECRET'
  }
}
authManager.configureProvider("twitter", config.twitter);
```

The `consumer_key` and `consumer_secret` values are _generally_ provided by the provider development program. In the case of [twitter](https://apps.twitter.com), we can create an app and generate these values through their [development dashboard](https://apps.twitter.com).

### Implemented providers

The following list are the providers we've implemented thus far in `react-native-oauth` and the _required_ keys to pass when configuring the provider:

* Twitter
  * consumer_key
  * consumer_secret
* Facebook (not fully implemented)
  * consumer_key
  * consumer_secret

## Authenticating against our providers

In order to make any authenticated calls against a provider, we need to authenticate against it. The `react-native-oauth` library passes through an easy method for dealing with authentication with the `authorizeWithCallbackURL()` method.

Using the app uri we previous setup, we can call the `authorizeWithCallbackURL()` method to ask iOS to redirect our user to a browser where they can log in to our app in the usual flow. When the user authorizes the login request, the promise returned by the `authorizeWithCallbackURL()` is resolved. If they reject the login request for any reason, the promise is rejected along with an error, if there are any.

```javascript
authManager.authorizeWithCallbackURL('twitter', 'firebase-example://oauth-callback/twitter')
.then((oauthResponse) => {
  // the oauthResponse object is the response returned by the request
  // which is later stored by react-native-oauth using AsyncStorage
})
.catch((err) => {
  // err is an error object that contains the reason the user
  // error rejected authentication.
})
```

When the response is returned, `react-native-oauth` will store the resulting credentials using the `AsyncStorage` object provided natively by React Native. All of this happens behinds the scenes _automatically_. When the credentials are successfully rerequested, `AsyncStorage` is updated behind the scenes automatically. All you have to do is take care of authenticating the user using the `authorizeWithCallbackURL()` method.

## Calling a provider's API

Lastly, we can use our new oauth token to make requests to the api to make authenticated, signed requests. For instance, to get a list of the mentions on twitter, we can make a request at the endpoint: `'https://api.twitter.com/1.1/statuses/user_timeline.json'`. Provided our user has been authorized (or previously authorized), we can make a request using these credentials using the `makeRequest()` method. The `makeRequest()` method accepts between three and five parameters and returns a promise:

1. The provider our user is making a request (twitter, facebook, etc)
2. The HTTP method to use to make the request, for instance `get` or `post`
3. The URL to make the request
4. (optional) parameters to pass through directly to the request
5. (optional) headers are any headers associated with the request

```javascript
const userTimelineUrl = 'https://api.twitter.com/1.1/statuses/user_timeline.json';
authManager.makeRequest('twitter', 'get', userTimelineUrl)
  .then(resp => {
    // resp is an object that includes both a `response` object containing
    // details of the returned response as well as a `data` object which is
    // a STRING of the returned data. OAuthManager makes zero assumptions of
    // the data type when returned and instead passes through the string response
  })
  .catch(err => {
    // err is an object that contains the error called when the promise
    // is rejected
  })
```

## deauthorize()

We can `deauthorize()` our user's from using the provider by calling the `deauthorize()` method. It accepts a single parameter:

1. The `provider` we want to remove from our user credentials.

```javascript
authManager.deauthorize('twitter');
```

## Contributing

This is _open-source_ software and we can make it rock for everyone through contributions.

## Contributing

```shell
git clone https://github.com/fullstackreact/react-native-oauth-manager.git
cd react-native-oauth-manager
npm install
```
___

## TODOS:

[] Handle rerequesting tokens (automatically?)
[] Simplify method of adding providers
  [] Complete [facebook](https://developers.facebook.com/docs/facebook-login) support
  [] Add [github](https://developer.github.com/v3/oauth/) support
  [] Add [Google]() support
[] Add Android support
