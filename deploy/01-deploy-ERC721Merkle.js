const { network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");
const keccak256 = require("keccak256");
const { MerkleTree } = require("merkletreejs");

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();

    // Generate set of tickets for special users
    const ticket1 = "1";
    const ticket2 = "2";
    const ticket3 = "3";
    const ticket4 = "4";
    const ticket5 = "5";
    const ticket6 = "6";

    // Generate set of special users that can enter the presale pass in this in the arguments when trying to use
    // the bitmap approach so instead of signing the transaction with the ticket as data and verifying the signature
    // and if the user already used his ticket and is approved for that ticket we can just include the ticketnumber in
    // the address hash on this case my address has ticket nr 1 & 6
    const approvedAddressesForPresaleWithBitmap = [
        "0xe4064d8E292DCD971514972415664765e51B5364" + ticket1,
        "0x98697033803CEf8bdDB7CA883786CfA9a96F2Be4" + ticket2,
        "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" + ticket3,
        "0xb7e390864a90b7b923c9f9310c6f98aafe43f707" + ticket4,
        "0xea674fdde714fd979de3edf0f56aa9716b898ec8" + ticket5,
        "0xe4064d8E292DCD971514972415664765e51B5364" + ticket6,
    ];

    // Generate set of special users that can enter the presale
    // const approvedAddressesForPresale = [
    //     "0xe4064d8E292DCD971514972415664765e51B5364",
    //     "0x98697033803CEf8bdDB7CA883786CfA9a96F2Be4",
    //     "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    //     "0xb7e390864a90b7b923c9f9310c6f98aafe43f707",
    //     "0xea674fdde714fd979de3edf0f56aa9716b898ec8",
    //     "0x054b7Ca525a58326162b916360166881dEB5F9C3",
    // ];

    // Get proofs which will be passed into the constructor
    const proofsWithBitmap = approvedAddressesForPresaleWithBitmap.map(
        (address) =>
            keccak256(
                Buffer.concat([Buffer.from(address.replace("0x", ""), "hex")])
            )
    );
    // const proofs = approvedAddressesForPresale.map((address) =>
    //     keccak256(
    //         Buffer.concat([Buffer.from(address.replace("0x", ""), "hex")])
    //     )
    // );

    // Create merkle tree for constructor
    const merkleTreeWithBitmap = new MerkleTree(proofsWithBitmap, keccak256, {
        sortPairs: true,
    });

    // const merkleTree = new MerkleTree(proofs, keccak256, {
    //     sortPairs: true,
    // });

    const royaltyFeeInBip = 250; // 250 => 2.5% royalty

    const argumentsWithBitmap = [
        merkleTreeWithBitmap.getHexRoot(),
        royaltyFeeInBip,
    ];
    // const arguments = [merkleTree.getHexRoot(), royaltyFeeInBip];

    const erc721Merkle = await deploy("ERC721Merkle", {
        from: deployer,
        args: argumentsWithBitmap,
        logs: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    });

    // only verify the code when not on development chains as hardhat
    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY
    ) {
        log("Verifying...");
        await verify(erc721Merkle.address, argumentsWithBitmap);
    }
    log("deployed successfully at:", erc721Merkle.address);
    log("-----------------------------------------");
};

module.exports.tags = ["all", "erc721Merkle"];
