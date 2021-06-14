import {DeployFunction} from 'hardhat-deploy/types';
import 'hardhat-deploy-ethers';
import 'hardhat-deploy';
import {defaultAbiCoder} from '@ethersproject/abi';

const run: DeployFunction = async (hre) => {
  const {deployments, getNamedAccounts} = hre;
  const {deploy, execute} = deployments;
  const {creator} = await getNamedAccounts();
  const sushiSwapRouter = {address: '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506'};
  const quickswapRouter = {address: '0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff'};
  const titan = {address: '0xaAa5B9e6c589642f98a1cDA99B9D024B8407285A'};
  const iron = {address: '0xD86b5923F3AD7b585eD81B448170ae026c65ae9a'};
  const usdc = {address: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174'};
  const wmatic = {address: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270'};
  const weth = {address: '0x7ceb23fd6bc0add59e62ac25578270cff1b9f619'};
  const quick = {address: '0x831753dd7087cac61ab5644b308642cc1c33dc13'};

  const policy = await deploy('VaultPolicy', {
    from: creator,
    log: true,
  });

  const router = await deploy('Router', {from: creator, log: true});

  // route: titan -> iron
  await execute(
    'Router',
    {from: creator, log: true},
    'addRoute',
    titan.address,
    iron.address,
    sushiSwapRouter.address,
    [titan.address, wmatic.address, usdc.address, iron.address]
  );

  // route: iron -> titan
  await execute(
    'Router',
    {from: creator, log: true},
    'addRoute',
    iron.address,
    titan.address,
    sushiSwapRouter.address,
    [iron.address, usdc.address, wmatic.address, titan.address]
  );

  // route: titan -> usdc
  await execute(
    'Router',
    {from: creator, log: true},
    'addRoute',
    titan.address,
    usdc.address,
    sushiSwapRouter.address,
    [titan.address, wmatic.address, usdc.address]
  );

  // route: usdc -> titan
  await execute(
    'Router',
    {from: creator, log: true},
    'addRoute',
    usdc.address,
    titan.address,
    sushiSwapRouter.address,
    [usdc.address, wmatic.address, titan.address]
  );

  // route: titan -> wmatic
  await execute(
    'Router',
    {from: creator, log: true},
    'addRoute',
    titan.address,
    wmatic.address,
    sushiSwapRouter.address,
    [titan.address, wmatic.address]
  );

  // route: wmatic -> titan
  await execute(
    'Router',
    {from: creator, log: true},
    'addRoute',
    wmatic.address,
    titan.address,
    sushiSwapRouter.address,
    [wmatic.address, titan.address]
  );

  // route: quick -> eth
  await execute(
    'Router',
    {from: creator, log: true},
    'addRoute',
    quick.address,
    weth.address,
    quickswapRouter.address,
    [quick.address, weth.address]
  );

  // route: quick -> titan
  await execute(
    'Router',
    {from: creator, log: true},
    'addRoute',
    quick.address,
    titan.address,
    quickswapRouter.address,
    [quick.address, weth.address, titan.address]
  );

  // route: eth -> quick
  await execute(
    'Router',
    {from: creator, log: true},
    'addRoute',
    weth.address,
    quick.address,
    quickswapRouter.address,
    [weth.address, quick.address]
  );

  // route: titan -> quick
  await execute(
    'Router',
    {from: creator, log: true},
    'addRoute',
    titan.address,
    quick.address,
    quickswapRouter.address,
    [titan.address, weth.address, quick.address]
  );

  await deploy('VaultFactory', {
    from: creator,
    args: [],
    log: true,
  });

  await execute(
    'VaultFactory',
    {from: creator, log: true},
    'initialize',
    policy.address,
    router.address
  );

  const masterChefTitan1 = {address: '0x65430393358e55A658BcdE6FF69AB28cF1CbB77a'};
  const artifact_VaultIronLP = await deployments.getArtifact('VaultIronLP');

  // 0 vault: titan/matic
  const _argsPool0 = await defaultAbiCoder.encode(
    ['address', 'address', 'uint256'],
    [sushiSwapRouter.address, masterChefTitan1.address, 0]
  );
  await execute(
    'VaultFactory',
    {from: creator, log: true},
    'addTemplate',
    artifact_VaultIronLP.bytecode,
    _argsPool0
  );

  // 1 vault: iron/usdc sushiswap
  const _argsPool1 = await defaultAbiCoder.encode(
    ['address', 'address', 'uint256'],
    [sushiSwapRouter.address, masterChefTitan1.address, 1]
  );
  await execute(
    'VaultFactory',
    {from: creator, log: true},
    'addTemplate',
    artifact_VaultIronLP.bytecode,
    _argsPool1
  );

  // 2 vault: iron/usdc quickswap
  const _argsPool2 = await defaultAbiCoder.encode(
    ['address', 'address', 'uint256'],
    [quickswapRouter.address, masterChefTitan1.address, 2]
  );
  await execute(
    'VaultFactory',
    {from: creator, log: true},
    'addTemplate',
    artifact_VaultIronLP.bytecode,
    _argsPool2
  );

  // 3 vault: titan/iron sushiswap
  const masterChefTitan2 = {address: '0xb444d596273C66Ac269C33c30Fbb245F4ba8A79d'};
  const _argsPool3 = await defaultAbiCoder.encode(
    ['address', 'address', 'uint256'],
    [sushiSwapRouter.address, masterChefTitan2.address, 0]
  );
  await execute(
    'VaultFactory',
    {from: creator, log: true},
    'addTemplate',
    artifact_VaultIronLP.bytecode,
    _argsPool3
  );

  // 4 vault: titan/eth quickswap
  const qsStakingReward_TitanEth = {address: '0x2dF6A6b1B7aA23a842948a81714a2279e603e32f'};
  const artifact_VaultQuickswapLP = await deployments.getArtifact('VaultQuickswapLP');
  const _argsPool4 = await defaultAbiCoder.encode(
    ['address', 'address'],
    [quickswapRouter.address, qsStakingReward_TitanEth.address]
  );
  await execute(
    'VaultFactory',
    {from: creator, log: true},
    'addTemplate',
    artifact_VaultQuickswapLP.bytecode,
    _argsPool4
  );
};

run.tags = ['matic', 'v1'];

run.skip = async (hre) => {
  return hre.network.name !== 'matic';
};
export default run;
