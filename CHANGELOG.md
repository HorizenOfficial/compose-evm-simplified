**1.0.0**
* This release introduces new changes to the network logistics that requires the following steps ONLY for the **UPGRADE** process(not a fresh start).
  1. Stop evmapp 
  2. Get the latest version of `.env` file
  3. Delete `peers/` directory from `evmapp-data` docker volume(/var/lib/docker/volmes)
  4. Start evmapp