```
starkli account fetch 0x...

starkli declare target/dev/ticket1_TicketStarknet.contract_class.json --account ~/.starkli-wallets/deployer/account.json  --private-key $(echo $STARKNET_PRIVATE_KEY)


starkli deploy 0x01facdad7258467b73e8ed286f811d6721023a343eaa38d58f9c027a1e03ccd1 --account ~/.starkli-wallets/deployer/account.json  --private-key $(echo $STARKNET_PRIVATE_KEY) 0x07a53e16d8E8D7d4F8981AAE00F65dDC220f9deA62918c2e63E4670C89f60ED4
```