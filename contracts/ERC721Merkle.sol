// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "../node_modules/@openzeppelin/contracts/utils/Strings.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/common/ERC2981.sol";
import "../node_modules/@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// QUESTION: Merkle trees are only cost effective for ~32 or fewer addressses as stated in GitHub Repo whats the other option for > 32?

// QUESTION: can we make those 2 constants a uint32 or something lower to save gas since we know the value and they are consts?
// QUESTION: token supply won't reach > 11 can we make that a lower uint as well?

// QUESTION: In the solidity course of Patrick Collins we learnt strings in solidity are basically an array so it's cheaper to make an if check
//           and return a custom error instead? Is it good practice or did something change in the last year / months?
// QUESTION: We also learnt the coding convention wirting storage variables with s as a prefix and private variables with _ as a prefix
//           and immutables with i as a prefix, is this still the "best practice"?

/*
 * @title A basic NFT contract with Bitmap Merkle Tree Presale
 * @author Patrick Zimmerer
 * @notice This contract is NOT FOR PRODUCTION, just for learning purposes
 * @dev implements ERC721
 */
contract RareNFTMerkle is ERC721, ERC2981 {
    // using uints which are slightly more efficient than bools because the EVM casts bools to uint
    mapping(address => uint256) public hasClaimed;

    // for public signatures
    address public allowListSigningAddress = address(1337);

    // for merkle tree
    bytes32 public merkleRoot;

    /* State Variables */
    uint256 public tokenSupply = 1;
    uint256 public constant MAX_SUPPLY = 11;
    uint256 public constant PRICE = 0.000001 ether;
    uint256 public constant PRESALE_PRICE = 0.0000001 ether;
    /* Owner */
    address immutable deployer;

    constructor(bytes32 _root) ERC721("RareNFTMerkle", "RNM") {
        deployer = msg.sender;
        merkleRoot = _root;
    }

    function mint() external payable {
        require(tokenSupply < MAX_SUPPLY, "Max Supply reached.");
        require(msg.value == PRICE, "Not enough ETH sent.");
        _mint(msg.sender, tokenSupply);
        tokenSupply++;
    }

    /*
     * @title Presale function that let's specific users mint for half the price at presale ( only once )
     * @author Patrick Zimmerer
     * @notice only for users in our special users set
     * @dev should reduce the cost of the first mint by special users and add the user to the mapping isClaimed
     */
    function presale(bytes32[] calldata _merkleProof) external payable {
        // require user already used presale => check with mapping
        require(
            hasClaimed[msg.sender] == 0,
            "Already claimed the presale NFT."
        );
        // require user in set of addresses !
        require(tokenSupply < MAX_SUPPLY, "Max Supply reached.");
        require(msg.value == PRESALE_PRICE, "Not enough ETH sent.");

        // create a leaf node from the caller of this function
        bytes32 leaf = keccak256(abi.encode(msg.sender));
        require(isValid(_merkleProof, leaf), "Invalid Merkle Proof");
        _mint(msg.sender, tokenSupply);
        tokenSupply++;
        // setting the user on the hasClaimed map after _mint with presale
        hasClaimed[msg.sender] = 1;
    }

    function isValid(
        bytes32[] memory _merkleProof,
        bytes32 leaf
    ) public view returns (bool) {
        return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
    }

    /*
     * @dev since implemented in ERC721 & ERC2981 it needs to be overwritten
     * QUESTION: Do I need to comment things like this which are trivial since the contracts are listed underneath
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, ERC2981) returns (bool) {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /* View / Pure functions */
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmX597cEg8LCFbND2YwFsFd7SmiSr8sNQq1GWyKv7u3tYR/";
    }

    function viewBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() external {
        payable(deployer).transfer(address(this).balance);
    }
}
