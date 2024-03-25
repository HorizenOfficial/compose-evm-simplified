# Migration from 1.2.* to 1.3.0

This project has been completely restructured in version 1.3.0. The main changes are:

- Compose file templates have been moved to [compose_files](../compose_files) folder.
- Environment variables file templates have been moved to [env](../env) folder. There is now a specific template for each network (eon vs gobi) and type of node (rpc vs forger).
- New init script is provided to help to set up the project. This is an interactive script that will help to create the required files and folders in [deployments](../deployments) folder.
- Updated documentation that will help to set up and run a forger or a rpc node.

If you are using version 1.2.* of this project, you will need to follow these steps to migrate to version 1.3.0:

1. Make a copy of your .env file. This file contains some secrets that you will need to keep.
2. Stop the running containers. You can use the `docker compose down` command to stop and remove the containers. **DO NOT REMOVE THE VOLUMES**.
3. Pull the new tag 1.3.0 of the project. To do so run `git pull && git checkout 1.3.0`.
4. Run the init script in order to set up the new structure of the project.
5. When requested by the script provide the already generated SCNODE_WALLET_SEED available in the old .env file.
6. Review the new .env file and update the values if necessary. For instance RPC or REST passwords, or node names.
7. Run the `docker compose up -d` command to start the new containers. See the [README](../README.md) for more information. 
8. Go back to [README](../README.md) and execute the second step, regarding the [upgrade.sh](./scripts/upgrade.sh) script.
The nodes should start and use the old volumes and data, so there should be no need to resync the nodes.
