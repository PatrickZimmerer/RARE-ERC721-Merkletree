const networkConfig = {
	5: {
		name: 'goerli',
	},
	31337: {
		name: 'hardhat',
	},
};

const developmentChains = ['hardhat', 'localhost'];
const VERIFICATION_BLOCK_CONFIRMATIONS = 3;

module.exports = {
	networkConfig,
	developmentChains,
	VERIFICATION_BLOCK_CONFIRMATIONS,
};
