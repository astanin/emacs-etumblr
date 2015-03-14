# etumblr: Tumblr OAuth for Emacs

This module allows to authorize an Emacs app to use Tumblr API v2.
It allows to post a simple text message.

## Usage

0. Save [etumblr.el](https://raw.githubusercontent.com/astanin/etumblr/master/etumblr.el)
   in your Emacs `load-path`.

1. Register your app, set callback to "http://localhost:12345/",
   obtain OAuth Consumer Key and Secret:

  [http://www.tumblr.com/oauth/apps](http://www.tumblr.com/oauth/apps)

2. Get user authorization:

   ```
   (require 'etumblr)
   (setq access-token
     (etumblr-authorize-app "OAUTH-CONSUMER-KEY" "SECRET-KEY"))
  ```

3. Upon sucess, try to post a message:

  ```
  (etumblr-post-text access-token "example.tumblr.com"
    "Hello world!" "Sincerely yours,\n\n_Emacs_")
  ```
  
## Dependencies

 * [oauth.el](https://github.com/psanford/emacs-oauth) by Peter Sanford to do the hard work
 * [elnode.el](https://github.com/nicferrier/elnode) by Nic Ferrier to run HTTP server and receive the callback


## Distribution

Public domain
