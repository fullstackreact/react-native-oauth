import invariant from 'invariant';
import {Type, Object, String} from 'valib';

const notEmpty = (str) => Type.isString(str) && !String.isEmpty(str);
const isValid = (str, validations=[]) => {
  return validations
            .map(fn => !fn(str))
            .filter(bool => bool)
            .length === 0;
}
const validate = (obj={}) => {
  Object.keys(obj)
        .map(property => isValid(property, obj[property]))
        .filter(bool => !bool)
        .length === 0;
}

export const authProviders = {
  'twitter': {
    auth_version: "1.0",
    defaults: {
      request_token_url: 'https://api.twitter.com/oauth/request_token',
      authorize_url: 'https://api.twitter.com/oauth/authorize',
      access_token_url: 'https://api.twitter.com/oauth/access_token'
    },
    isValid: ({client_id, client_secret}) => validate({
        client_id: [notEmpty],
        client_secret: [notEmpty]
      })
  },
  'facebook': {
    auth_version: '2.0',
    defaults: {
      authorize_url: 'https://graph.facebook.com/oauth/authorize'
    },
    isValid: ({}) => true
  }
}

export default authProviders;