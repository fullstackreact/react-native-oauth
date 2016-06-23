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

## Installation



## Features

* Isolates the OAuth experience to a few simple methods.
* Stores OAuth token credentials away for safe-keeping (using React Native's [AsyncStorage](https://facebook.github.io/react-native/docs/asyncstorage.html)) so you don't have to deal with it at all.
* Works with many providers and relatively simple to add a provider

## TODOS:

* Handle rerequesting tokens (automatically?)
* Simplify method of adding providers
