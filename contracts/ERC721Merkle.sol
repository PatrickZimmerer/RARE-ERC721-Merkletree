// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/*
 * @title A basic NFT contract with Bitmap Merkle Tree Presale
 * @author Patrick Zimmerer
 * @notice This contract is NOT FOR PRODUCTION, just for learning purposes
 * @dev implements ERC721
 */
contract ERC721Merkle is ERC721, ERC2981 {
    // using uints which are slightly more efficient than bools because the EVM casts bools to uint
    mapping(address => uint256) public canUserPresale;

    // merkle tree
    bytes32 private merkleRoot;

    // bitmap
    uint16 private constant MAX_INT = 0xffff;
    // uint16[1] bitmap = [MAX_INT];
    uint16 private ticketGroup0 = MAX_INT;
    uint16 private constant MAX_TICKETS = 1 * 15;

    /* State Variables */
    uint256 public tokenSupply = 1;
    uint256 private constant MAX_SUPPLY = 11;
    uint256 public constant PRICE = 0.000001 ether;
    uint256 public constant PRESALE_PRICE = 0.0000005 ether; // 50% off

    /* Owner */
    address immutable deployer;

    constructor(
        bytes32 _merkleRoot,
        uint96 _royaltyFeeInBips
    ) ERC721("RareNFTMerkle", "RNM") {
        deployer = _msgSender();
        merkleRoot = _merkleRoot;
        setRoyaltyInfo(_msgSender(), _royaltyFeeInBips);
    }

    // --------------------------------------------------------------------------------------------------------

    /*
     * @title Basic minting function
     * @notice every user can mint as many NFT until the maxSupply is reached
     * @dev calls the _safeMint method to avoid sending NFTs to non ERC721Receiver contracts
     */
    function mint(address _to) external payable {
        uint256 _tokenSupply = tokenSupply; // added local variable to reduce gas cost (amount of READs)
        require(_tokenSupply < MAX_SUPPLY, "Max Supply reached.");
        require(msg.value == PRICE, "Not enough ETH sent.");
        unchecked {
            tokenSupply = _tokenSupply + 1; // added unchecked block since overflow check gets handled by require MAX_SUPPLY
        }
        _safeMint(_to, _tokenSupply);
    }

    // -------------------------   PRESALE WITH MAPPING CHECK   -------------------------

    /*
     * @title Presale function that let's specific users mint for half the price at presale (only once)
     * @notice only for users in our special users set
     * @dev should reduce the cost of the first mint for special users and add the user to the mapping alreadyMinted
     */
    function presaleMapping(bytes32[] calldata _merkleProof) external payable {
        uint256 _tokenSupply = tokenSupply; // added local variable to reduce gas cost
        require(_tokenSupply < MAX_SUPPLY, "Max Supply reached.");
        require(msg.value == PRESALE_PRICE, "Not enough ETH sent.");
        bytes32 leaf = keccak256(abi.encode(_msgSender())); // create a leaf node from the caller of this function
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Invalid Merkle Proof. User not allowed to do a presale mint"
        ); // require user address in whitelist for presale!
        require(
            canUserPresale[_msgSender()] < 1,
            "Already claimed the presale mint."
        ); // user should only be able to claim presale once => check with MAPPING
        canUserPresale[_msgSender()]++; // setting the users amountLeftToMint on the map after _mint
        unchecked {
            tokenSupply = _tokenSupply + 1; // added unchecked block since overflow check gets handled by require MAX_SUPPLY
        }
        _safeMint(_msgSender(), _tokenSupply);
    }

    // -------------------------   PRESALE WITH BITMAP CHECK LIKE IN ARTICLE  -------------------------
    /*
     * @title Presale function that let's specific users mint for half the price at presale (only once)
     * @notice only for users in our special users set
     * @dev should reduce the cost of the first mint for special users and should update the users
     */

    function presaleBitmap(
        uint16 _ticketNumber,
        bytes32[] calldata _merkleProof
    ) external payable {
        uint256 _tokenSupply = tokenSupply; // added local variable to reduce gas cost
        require(_tokenSupply < MAX_SUPPLY, "Max Supply reached.");
        require(msg.value == PRESALE_PRICE, "Not enough ETH sent.");
        bytes32 leaf = keccak256(abi.encode(_msgSender(), _ticketNumber)); // create a leaf node from the caller + _ticketNumber
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Invalid Merkle Proof. User not allowed to do a presale mint"
        ); // require user in whitelisted set of addresses for presale!
        claimTicketOrBlockTransaction(_ticketNumber);
        unchecked {
            tokenSupply = _tokenSupply + 1; // added unchecked block since overflow check gets handled by require MAX_SUPPLY
        }
        _safeMint(_msgSender(), _tokenSupply);
    }

    function claimTicketOrBlockTransaction(uint16 ticketNumber) internal {
        uint16 storageSlot = 0; // since it's only a single entry => 0
        uint16 offsetWithin16;
        uint16 localGroup;
        uint16 storedBit;
        unchecked {
            offsetWithin16 = ticketNumber % 16;
        }
        assembly {
            storageSlot := add(ticketGroup0.slot, storageSlot)
            localGroup := sload(storageSlot)
        }

        storedBit = (localGroup >> offsetWithin16) & uint16(1);
        require(storedBit == 1, "already taken");

        assembly {
            sstore(storageSlot, localGroup)
        }
    }

    function setMerkleRoot(bytes32 _merkleRoot) external {
        require(msg.sender == deployer, "You are not the owner");
        merkleRoot = _merkleRoot;
    }

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
