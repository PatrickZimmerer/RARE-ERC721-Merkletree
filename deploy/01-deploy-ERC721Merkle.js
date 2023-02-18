const { network, ethers } = require("hardhat");
const {
    networkConfig,
    developmentChains,
} = require("../helper-hardhat-config");
const keccak256 = require("keccak256");
const { MerkleTree } = require("merkletreejs");
const { verify } = require("../utils/verify");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = network.config.chainId;

    let approvedAddressesForPresale = [
        "0xe4064d8E292DCD971514972415664765e51B5364",
        "0x98697033803CEf8bdDB7CA883786CfA9a96F2Be4",
        "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "0xb7e390864a90b7b923c9f9310c6f98aafe43f707",
        "0xea674fdde714fd979de3edf0f56aa9716b898ec8",
        "0x054b7Ca525a58326162b916360166881dEB5F9C3",
    ];

    const leafNodes = approvedAddressesForPresale.map((address) =>
        keccak256(
            Buffer.concat([Buffer.from(address.replace("0x", ""), "hex")])
        )
    );

    const merkleTree = new MerkleTree(leafNodes, keccak256, {
        sortPairs: true,
    });

    console.log("---------");
    console.log("Merkle Tree");
    console.log(merkleTree.toString());
    console.log("Merkle Root: " + merkleTree.getHexRoot());

    console.log("Proofs: " + merkleTree.getHexProofs());
    console.log("Proof 2: " + merkleTree.getHexProof(leafNodes[1]));

    const arguments = [
        approvedAddressesForPresale,
        merkleTree.getHexRoot(),
        leafNodes,
    ];
    const erc721Merkle = await deploy("ERC721Merkle", {
        from: deployer,
        args: arguments,
        logs: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    });

    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY
    ) {
        log("Verifying...");
        await verify(erc721Merkle.address, arguments);
    }
    log("-----------------------------------------");
};

module.exports.tags = ["all", "raffle"];
