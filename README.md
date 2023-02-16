# verkle-scripts
Various scripts for verkle testing

## Verkle transition scripts

### Tree conversion script in `transition/conversion.rb`

TODO, the first hardfork will be manual

### Client transition script in `transition/main.rb`

This script is an RPC proxy that forwards RPC calls from the CL to both a MPT-enabled EL, and a verkle-enabled EL. The forwarding depends on the mode that the script works in, and is detailed in both an upcoming writeup and this cryptic picture:

![image](https://user-images.githubusercontent.com/3272758/219324606-aaaf77e7-d5a7-400c-8ca1-941b961db10e.png)

#### Preparing the script

make sure that `bundler` is install and then install the dependencies:

```
$ bundle config path vendor/bundler
$ bundle install
```

Edit the configuration file `config.yml` in the same directory:

```
---
fork_block: <block at which the switcv from MPT to VKT, pick a target block>
mpt_url: <URL of the MPT-enbaled EL>
vkt_url: <URL of the VKT-enabled EL>
provider_url: <URL of the conversion script, set to "" for the manual process>
```

#### Running the script

```
$ bundle exec ./main.rb
```
