#!/bin/bash

read -p "Enter network: " network
read -p "Enter func [migrate/verify/build]: " func

if [ $func == 'migrate' ]; then
  read -p "Enter the number of migration file: " migration_number
  ./node_modules/.bin/truffle migrate --network $network -f $migration_number --to $migration_number
elif [ $func == 'verify' ]; then
  read -p "Enter name of the contract: " contract_name
  ./node_modules/.bin/truffle run verify $contract_name --network=$network
elif [ $func == 'build' ]; then
  ./node_modules/.bin/truffle build
else
  echo "Invalid func!"
fi