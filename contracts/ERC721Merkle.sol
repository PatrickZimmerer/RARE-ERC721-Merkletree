// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// QUESTION: can we make those 2 constants a uint32 or something lower to save gas since we know the value and they are consts?
// QUESTION: token supply won't reach > 11 can we make that a lower uint as well? =>
// CONCLUSION: User will have to pay more because pulling a uint <256 from storage forces the evm to cast it to a uint256
// => cheaper at deployment but more expensive for the end user
// ANSWER:

// QUESTION: Merkle trees are only cost effective for ~32 or fewer addressses as stated in GitHub Repo whats the other option for > 32?
// ANSWER:

// QUESTION: When should we use the _ on variables I just know those marking a private variable / method but sometimes
//           they are used in input variables and sometimes not its quite confusing and I don't see a clear pattern
// ANSWER:

// QUESTION: We also learnt the coding convention wirting storage variables with s as a prefix and private variables with _ as a prefix
//           and immutables with i as a prefix, is this still the "best practice"?
// ANSWER:

// QUESTION: merkleProof will be generated offChain in a database and the user will send it with the transaction?
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
    // mapping(address => uint256) public canUserPresale;

    // merkle tree
    bytes32 private immutable merkleRoot;

    // bitmap
    uint16 private constant MAX_INT = 0xffff;
    // uint16[1] bitmap = [MAX_INT];
    uint16 private ticketGroup0 = MAX_INT;
    uint16 private constant MAX_TICKETS = 1 * 16;

    /* State Variables */
    uint256 public tokenSupply = 1;
    uint256 public constant MAX_SUPPLY = 11;
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
        setRoyaltyInfo(_msgSender(), _royaltyFeeInBips); // first param is royaltyReceiver could be set to other address through the constructor
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
    // function presaleMapping(bytes32[] calldata _merkleProof) external payable {
    //     uint256 _tokenSupply = tokenSupply; // added local variable to reduce gas cost
    //     require(_tokenSupply < MAX_SUPPLY, "Max Supply reached.");
    //     require(msg.value == PRESALE_PRICE, "Not enough ETH sent.");
    //     bytes32 leaf = keccak256(abi.encode(_msgSender())); // create a leaf node from the caller of this function
    //     require(
    //         MerkleProof.verify(_merkleProof, merkleRoot, leaf),
    //         "Invalid Merkle Proof. User not allowed to do a presale mint"
    //     ); // require user address in whitelist for presale!
    //     require(
    //         canUserPresale[_msgSender()] < 1,
    //         "Already claimed the presale mint."
    //     ); // user should only be able to claim presale once => check with MAPPING
    //     canUserPresale[_msgSender()]++; // setting the users amountLeftToMint on the map after _mint
    //     unchecked {
    //         tokenSupply = _tokenSupply + 1; // added unchecked block since overflow check gets handled by require MAX_SUPPLY
    //     }
    //     _safeMint(_msgSender(), _tokenSupply);
    // }

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
        require(ticketNumber < MAX_SUPPLY, "That ticket doesn't exist");
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

// ------------------ Redundant bc of improved merkleProof offChain ------------------

// function verifySignature(
//     uint16 _ticketNumber,
//     bytes calldata _signature,
//     address _signer
// ) public pure returns (bool) {
//     bytes32 ticketNumberHash = keccak256(
//         abi.encodePacked("\x19Ethereum Signed Message:\n2", _ticketNumber)
//     );
//     (bytes32 r, bytes32 s, uint8 v) = _split(_signature);
//     address recoveredSigner = ecrecover(ticketNumberHash, v, r, s);
//     return recoveredSigner == _signer;
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
