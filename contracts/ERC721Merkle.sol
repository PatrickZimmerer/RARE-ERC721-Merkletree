// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

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
// ANSWER:

// QUESTION: We also learnt the coding convention wirting storage variables with s as a prefix and private variables with _ as a prefix
//           and immutables with i as a prefix, is this still the "best practice"?
// ANSWER:

// QUESTION: about merkleProof did I do that right and put it as an inupt Param into constructor so the logic can happen off chain,
//           can we also move the merkleProof array offChain somehow in a database (later on obviously)?
// ANSWER:

// QUESTION: Can I handle both cases (presale & casual mint) in one function to save gas?
// ANSWER:

// QUESTION: Should I have adjusted the metadata which the NFT returns (_baseUri) to specify the seller_fee_basis_points (250 => 2.5%) & fee_recipient
//           which is needed on older nft market places like opensea to make those royalties availible there
// ANSWER:

// QUESTION: Is there a way to check gas efficiency without wrting tests and using the gas reporter ?
// ANSWER:

/*
 * @title A basic NFT contract with Bitmap Merkle Tree Presale
 * @author Patrick Zimmerer
 * @notice This contract is NOT FOR PRODUCTION, just for learning purposes
 * @dev implements ERC721
 */
contract ERC721Merkle is ERC721, ERC2981 {
    // using uints which are slightly more efficient than bools because the EVM casts bools to uint
    mapping(address => uint256) public canUserMint;

    // merkle tree
    bytes32 private immutable i_merkleRoot;
    bytes32[] private _merkleProof;

    // bitmap my try
    mapping(address => uint16) private canUserMintBitmaps;
    uint8 constant INTERACTION_PRESALE_INDEX = 1;

    // bitmap Jeffrey
    uint16 private constant MAX_INT = 0xffff;
    uint16[1] arr = [MAX_INT];

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

    /*
     * @title Basic minting function
     * @notice every user can mint as many NFT as the maxSupply supplies
     * @dev when passing the checks it calls the internal _mint function in ERC721
     */
    function mint() external payable {
        uint256 _tokenSupply = tokenSupply; // added local variable to reduce gas cost (amount of READs)
        require(_tokenSupply < MAX_SUPPLY, "Max Supply reached.");
        require(msg.sender == tx.origin, "no bots"); // block smart contracts from minting
        require(msg.value == PRICE, "Not enough ETH sent.");
        _mint(msg.sender, _tokenSupply);
        unchecked {
            _tokenSupply++; // added unchecked block since overflow check gets handled by require MAX_SUPPLY
        }
        tokenSupply = _tokenSupply;
    }

    // -------------------------   PRESALE WITH MAPPING CHECK   -------------------------

    /*
     * @title Presale function that let's specific users mint for half the price at presale ( only once )
     * @notice only for users in our special users set
     * @notice Im aware of users can use presale twice now through persaleMapping and presaleBitmap
     * @dev should reduce the cost of the first mint by special users and add the user to the mapping alreadyMinted
     */
    function presaleMapping() external payable {
        uint256 _tokenSupply = tokenSupply; // added local variable to reduce gas cost
        require(_tokenSupply < MAX_SUPPLY, "Max Supply reached.");
        require(msg.value == PRESALE_PRICE, "Not enough ETH sent.");
        require(msg.sender == tx.origin, "No bots"); // block smart contracts from minting
        bytes32 leaf = keccak256(abi.encode(msg.sender)); // create a leaf node from the caller of this function
        require(
            MerkleProof.verify(_merkleProof, i_merkleRoot, leaf),
            "Invalid Merkle Proof. User not allowed to do a presale mint"
        ); // require user in whitelisted set of addresses for presale!
        require(
            canUserMint[msg.sender] < 1,
            "Already claimed the presale mint."
        ); // user should only be able to claim presale once => check with MAPPING
        canUserMint[msg.sender]++; // setting the users amountLeftToMint on the map after _mint

        unchecked {
            _tokenSupply++; // added unchecked block since overflow check gets handled by require MAX_SUPPLY
        }
        tokenSupply = _tokenSupply;
        _mint(msg.sender, _tokenSupply);
    }

    // -------------------------   PRESALE WITH BITMAP CHECK   -------------------------
    /*
     * @title Presale function that let's specific users mint for half the price at presale ( only once )
     * @notice only for users in our special users set
     * @notice Im aware of users can use presale twice now through persaleMapping and presaleBitmap
     * @dev should reduce the cost of the first mint by special users and add the user to the mapping alreadyMinted
     */

    function presaleBitmap() external payable {
        uint256 _tokenSupply = tokenSupply; // added local variable to reduce gas cost
        require(_tokenSupply < MAX_SUPPLY, "Max Supply reached.");
        require(msg.value == PRESALE_PRICE, "Not enough ETH sent.");
        require(msg.sender == tx.origin, "No bots"); // block smart contracts from minting
        bytes32 leaf = keccak256(abi.encode(msg.sender)); // create a leaf node from the caller of this function
        require(
            MerkleProof.verify(_merkleProof, i_merkleRoot, leaf),
            "Invalid Merkle Proof. User not allowed to do a presale mint"
        ); // require user in whitelisted set of addresses for presale!
        require(
            canUserMintBitmap(msg.sender, INTERACTION_PRESALE_INDEX),
            "Already claimed the presale NFT."
        ); // user should only be able to claim presale once => check with BITMAP
        setUserCanMintBitmap(msg.sender, INTERACTION_PRESALE_INDEX);
        unchecked {
            _tokenSupply++; // added unchecked block since overflow check gets handled by require MAX_SUPPLY
        }
        tokenSupply = _tokenSupply;
        _mint(msg.sender, _tokenSupply);
    }

    function setUserCanMintBitmap(address user, uint8 interactionIndex) public {
        require(interactionIndex < 16, "Invalid interaction index");
        canUserMintBitmaps[user] |= uint16(1) << interactionIndex;
    }

    function canUserMintBitmap(
        address user,
        uint8 interactionIndex
    ) public view returns (bool) {
        require(interactionIndex < 16, "Invalid interaction index");
        return canUserMintBitmaps[user] & (uint16(1) << interactionIndex) != 0;
    }

    // -------------------------   PRESALE WITH BITMAP CHECK LIKE IN ARTICLE  -------------------------
    /*
     * @title Presale function that let's specific users mint for half the price at presale ( only once )
     * @notice only for users in our special users set
     * @notice Im aware of users can use presale twice now through persaleMapping and presaleBitmap
     * @dev should reduce the cost of the first mint by special users and add the user to the mapping alreadyMinted
     */

    function presaleBitmapJeff(
        bytes calldata _signature,
        uint16 _ticketNumber
    ) external payable {
        uint256 _tokenSupply = tokenSupply; // added local variable to reduce gas cost
        require(_tokenSupply < MAX_SUPPLY, "Max Supply reached.");
        require(msg.value == PRESALE_PRICE, "Not enough ETH sent.");
        require(msg.sender == tx.origin, "No bots"); // block smart contracts from minting
        bytes32 leaf = keccak256(abi.encode(msg.sender)); // create a leaf node from the caller of this function
        require(
            MerkleProof.verify(_merkleProof, i_merkleRoot, leaf),
            "Invalid Merkle Proof. User not allowed to do a presale mint"
        ); // require user in whitelisted set of addresses for presale!
        require(
            verifySignature(_ticketNumber, _signature, msg.sender),
            "Invalid signature"
        );
        claimTicketOrBlockTransaction(_ticketNumber);
        unchecked {
            _tokenSupply++; // added unchecked block since overflow check gets handled by require MAX_SUPPLY
        }
        tokenSupply = _tokenSupply;
        _safeMint(msg.sender, _tokenSupply);
    }

    function verifySignature(
        uint16 _ticketNumber,
        bytes calldata _signature,
        address _signer
    ) public pure returns (bool) {
        bytes32 ticketNumberHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n2", _ticketNumber)
        );
        (bytes32 r, bytes32 s, uint8 v) = _split(_signature);
        address recoveredSigner = ecrecover(ticketNumberHash, v, r, s);
        return recoveredSigner == _signer;
    }

    function _split(
        bytes memory _signature
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(_signature.length == 65, "Invalid signature length");
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }
    }

    function claimTicketOrBlockTransaction(uint16 ticketNumber) internal {
        require(ticketNumber < MAX_SUPPLY, "That ticket doesn't exist");
        uint16 storageOffset = 0; // since it's an array with a single entry => 0
        uint16 offsetWithin16 = ticketNumber % 16;
        uint16 storedBit = (arr[storageOffset] >> offsetWithin16) & uint16(1);
        require(storedBit == 1, "already taken");

        arr[storageOffset] =
            arr[storageOffset] &
            ~(uint16(1) << offsetWithin16);
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

// ----------------  Hashing & verifying process split up into functions ----------------

// function verifySignature(
//     address _signer,
//     uint16 _ticketNumber,
//     bytes calldata _signature
// ) public pure returns (bool) {
//     bytes32 ticketNumberHash = getTicketNumberHash(_ticketNumber);
//     bytes32 ethSignedTicketNumberHash = getEthSignedTicketNumberHash(
//         ticketNumberHash
//     );
//     return recover(ethSignedTicketNumberHash, _signature) == _signer;
// }

// function getTicketNumberHash(
//     uint16 _ticketNumber
// ) public pure returns (bytes32) {
//     return keccak256(abi.encodePacked(_ticketNumber));
// }

// function getEthSignedTicketNumberHash(
//     bytes32 _ticketNumberHash
// ) public pure returns (bytes32) {
//     return
//         keccak256(
//             abi.encodePacked(
//                 "\x19Ethereum Signed Message:\n32",
//                 _ticketNumberHash
//             )
//         );
// }

// function recover(
//     bytes32 _ethSignedMessageHash,
//     bytes memory _signature
// ) public pure returns (address) {
//     (bytes32 r, bytes32 s, uint8 v) = _split(_signature);
//     ecrecover(_ethSignedMessageHash, v, r, s);
// }

// function _split(
//     bytes memory _signature
// ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
//     require(_signature.length == 65, "Invalid signature length");
//     assembly {
//         r := mload(add(_signature, 32))
//         s := mload(add(_signature, 64))
//         v := byte(0, mload(add(_signature, 96)))
//     }
// }
