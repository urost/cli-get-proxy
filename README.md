# cli-get-proxy

This is a small bash script that can be used to receive a proxy certificate
using [WaTTS](https://watts-dev.data.kit.edu).

## Purpose

**WaTTS** creates credentials for services that do not natively support OpenID Connect.
In this example, in order to receive a proxy certificate, this script relies on
**WaTTS** and *X509_RCauth_Pilot*  plugin to obtain a proxy certificate.

More info can be found when running:

```
cli-get-proxy -h
```
