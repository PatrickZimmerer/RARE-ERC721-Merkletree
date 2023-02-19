// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// QUESTION: Merkle trees are only cost effective for ~32 or fewer addressses as stated in GitHub Repo whats the other option for > 32?

// QUESTION: can we make those 2 constants a uint32 or something lower to save gas since we know the value and they are consts?
// QUESTION: token supply won't reach > 11 can we make that a lower uint as well? =>
// CONCLUSION: User will have to pay more because pulling a uint <256 from storage forces the evm to cast it to a uint256
// => cheaper at deployment but more expensive for the end user

// QUESTION: In the solidity course of Patrick Collins we learnt strings in solidity are basically an array so it's cheaper to make an if check
//           and return a custom error instead? Is it good practice or did something change in the last year / months?
// QUESTION: We also learnt the coding convention wirting storage variables with s as a prefix and private variables with _ as a prefix
//           and immutables with i as a prefix, is this still the "best practice"?

// QUESTION: about merkleProof did I do that right and put it as an inupt Param into constructor so the logic can happen off chain,
//           can we also move the merkleProof array offChain somehow in a database (later on obviously)?

// QUESTION: Can I handle both cases (presale & casual mint) in one function to save gas?

// QUESTION: Should I have adjusted the metadata which the NFT returns (_baseUri) to specify the seller_fee_basis_points (250 => 2.5%) & fee_recipient
//           which is needed on older nft market places like opensea to make those royalties availible there

/*
 * @title A basic NFT contract with Bitmap Merkle Tree Presale
 * @author Patrick Zimmerer
 * @notice This contract is NOT FOR PRODUCTION, just for learning purposes
 * @dev implements ERC721
 */
contract ERC721Merkle is ERC721, ERC2981 {
    // using uints which are slightly more efficient than bools because the EVM casts bools to uint
    mapping(address => uint256) public amountLeftToMint;

    // merkle tree
    bytes32 private immutable i_merkleRoot;
    bytes32[] private _merkleProof;

    // bitmap
    uint256 bitmap;
    uint256 private constant MAX_INT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256[1] public presaleBitmap = [MAX_INT];

    /* State Variables */
    uint256 public tokenSupply = 1;
    uint256 public constant MAX_SUPPLY = 11;
    uint256 public constant PRICE = 0.000001 ether;
    uint256 public constant PRESALE_PRICE = 0.0000005 ether; // 50% off

    /* Owner */
    address immutable deployer;

    constructor(
        bytes32[] memory merkleProof,
        bytes32 merkleRoot,
        uint96 royaltyFeeInBips
    ) ERC721("RareNFTMerkle", "RNM") {
        deployer = msg.sender;
        _merkleProof = merkleProof;
        i_merkleRoot = merkleRoot;
        setRoyaltyInfo(msg.sender, royaltyFeeInBips); // first param is royaltyReceiver could be set to other address through the constructor
    }

    // --------------------------------------------------------------------------------------------------------
    // TODO: Work on Bitmap
    // TODO: Work on Bitmap
    // TODO: Work on Bitmap

    /*
     * @title Basic minting function
     * @author Patrick Zimmerer
     * @notice every user can mint as many NFT as the maxSupply supplies
     * @dev when passing the checks it calls the internal _mint function in ERC721
     */
    function mint() external payable {
        uint256 _tokenSupply = tokenSupply; // added local variable to reduce gas cost
        require(_tokenSupply < MAX_SUPPLY, "Max Supply reached.");
        require(msg.sender == tx.origin, "no bots"); // block smart contracts from minting
        require(msg.value == PRICE, "Not enough ETH sent.");
        _mint(msg.sender, _tokenSupply);
        unchecked {
            _tokenSupply++; // added unchecked block since overflow check gets handled by require MAX_SUPPLY
        }
        tokenSupply = _tokenSupply;
    }

    /*
     * @title Presale function that let's specific users mint for half the price at presale ( only once )
     * @author Patrick Zimmerer
     * @notice only for users in our special users set
     * @dev should reduce the cost of the first mint by special users and add the user to the mapping alreadyMinted
     */
    function presale() external payable {
        uint256 _tokenSupply = tokenSupply; // added local variable to reduce gas cost
        require(_tokenSupply < MAX_SUPPLY, "Max Supply reached.");
        require(msg.sender == tx.origin, "no bots"); // block smart contracts from minting

        // create a leaf node from the caller of this function
        bytes32 leaf = keccak256(abi.encode(msg.sender));
        require(
            MerkleProof.verify(_merkleProof, i_merkleRoot, leaf),
            "Invalid Merkle Proof"
        ); // require user in whitelisted set of addresses for presale!
        require(
            amountLeftToMint[msg.sender] > 0,
            "Already claimed the presale NFT."
        ); // require user should only be able to claim presale once => check with mapping
        require(msg.value == PRESALE_PRICE, "Not enough ETH sent.");

        _mint(msg.sender, _tokenSupply);
        unchecked {
            _tokenSupply++; // added unchecked block since overflow check gets handled by require MAX_SUPPLY
        }

        amountLeftToMint[msg.sender]--; // setting the users amountLeftToMint on the map after _mint

        //TODO: Need to add to the bitmap to compare bitmap && mappings gas cost
        //TODO: Need to add to the bitmap to compare bitmap && mappings gas cost
        //TODO: Need to add to the bitmap to compare bitmap && mappings gas cost
        tokenSupply = _tokenSupply;
    }

    // --------------------------------------------------------------------------------------------------------

    /*
     * @title Sets royalty fee & receiver
     * @dev sets the royalty fee when contract is deployed
     */
    function setRoyaltyInfo(
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        _setDefaultRoyalty(receiver, feeNumerator);
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

    function totalSupply() external pure returns (uint256) {
        return MAX_SUPPLY - 1; // token supply starts at 1
    }
}
