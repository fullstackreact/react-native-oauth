import invariant from 'invariant';
import {Type, String} from 'valib';

const notEmpty = (str) => Type.isString(str) && !String.isEmpty(str) || 'cannot be empty';

const isValid = (prop, str, validations=[]) => {
  return validations
          .map(fn => {
            const val = fn(str);
            invariant(typeof val === 'boolean', `${prop} ${val}`)
          });
}
const validate = (props, obj={}) => Object.keys(props)
        .map(property => isValid(property, props[property], obj[property]));

export const authProviders = {
  'twitter': {
    auth_version: "1.0",
    request_token_url: 'https://api.twitter.com/oauth/request_token',
    authorize_url: 'https://api.twitter.com/oauth/authorize',
    access_token_url: 'https://api.twitter.com/oauth/access_token',

    validate: (props) => validate(props, {
      consumer_key: [notEmpty],
      consumer_secret: [notEmpty]
    })
  },
  'facebook': {
    auth_version: '2.0',
    authorize_url: 'https://graph.facebook.com/oauth/authorize',

    validate: (props) => validate(props, {
      client_id: [notEmpty],
      client_secret: [notEmpty]
    })
  }
}

export default authProviders;