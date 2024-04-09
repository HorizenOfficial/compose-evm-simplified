# Changelog

**1.3.0+2**
* SCNODE_FORGER_REWARD_ADDRESS implemented in EON version **1.3.0** added to the compose project as well as to the setup forger process.

**1.3.0+1**
* EON version: 1.3.0
* SDK version: 0.11.0
* Dynamic configuration for local docker uid:gid and volumes.
* PLEASE REFER TO THE [MIGRATION GUIDE](./docs/MIGRATION.md) FOR THE MIGRATION PROCESS FROM VERSION 1.2.*.

**1.3.0**
* EON version: 1.3.0 (see [EON changelog](https://github.com/HorizenOfficial/eon/blob/main/doc/release/1.3.0.md))
* SDK version: 0.11.0 (see [SDK changelog](https://github.com/HorizenOfficial/Sidechains-SDK/blob/0.11.0/CHANGELOG.md))
* Fork configuration to enable: EVM Update, Forger stake native smart contract new methods, Pause Forging feature
* PLEASE REFER TO THE [MIGRATION GUIDE](./docs/MIGRATION.md) FOR THE MIGRATION PROCESS FROM VERSION 1.2.*.

**1.2.1**
* SDK dependency updated to version 0.10.1
* [eth RPC endpoint] fix on json representation in RPC response of signature V field for transaction type 2.

**1.2.0**
* SDK dependency updated to version 0.10.0 (see [SDK changelog](https://github.com/HorizenOfficial/Sidechains-SDK/blob/master/CHANGELOG.md))
* Fork configuration to enable new functionalities (ZenIP 42203/42206 support, ZenDao Multisig support)

**1.1.0**
* SDK dependency updated to version 0.9.0
* Fork configuration to enable Native<>Real smart contract interoperability

**1.0.1**
* SDK dependency updated to version 0.8.1

**1.0.0**
* This release introduces new changes to the network logistics that requires the following steps ONLY for the **UPGRADE** process(not a fresh start).
  1. Stop evmapp 
  2. Get the latest version of `.env` file
  3. Delete `peers/` directory from `evmapp-data` docker volume(/var/lib/docker/volmes)
  4. Start evmapp
