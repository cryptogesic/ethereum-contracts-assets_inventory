// SPDX-License-Identifier: MIT

pragma solidity 0.6.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "./ERC1155InventoryBase.sol";

/**
 * @title ERC1155Inventory, a contract which manages up to multiple Collections of Fungible and Non-Fungible Tokens
 * @dev In this implementation, with N representing the Non-Fungible Collection mask length, identifiers can represent either:
 * (a) a Fungible Token:
 *     - most significant bit == 0
 * (b) a Non-Fungible Collection:
 *     - most significant bit == 1
 *     - (256-N) least significant bits == 0
 * (c) a Non-Fungible Token:
 *     - most significant bit == 1
 *     - (256-N) least significant bits != 0
 * with N = 32.
 *
 */
abstract contract ERC1155Inventory is ERC1155InventoryBase {
    using Address for address;

    //================================== ERC1155 =======================================/

    /// @dev See {IERC1155Inventory-safeTransferFrom(address,address,uint256,uint256,bytes)}.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public virtual override {
        address sender = _msgSender();
        require(to != address(0), "Inventory: transfer to zero");
        require(_isOperatable(from, sender), "Inventory: non-approved sender");

        if (isFungible(id)) {
            _transferFungible(from, to, id, value);
        } else if (id & _NF_TOKEN_MASK != 0) {
            _transferNFT(from, to, id, value, false);
        } else {
            revert("Inventory: not a token id");
        }

        emit TransferSingle(sender, from, to, id, value);
        if (to.isContract()) {
            _callOnERC1155Received(from, to, id, value, data);
        }
    }

    /// @dev See {IERC1155Inventory-safeBatchTransferFrom(address,address,uint256,uint256,bytes)}.
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override {
        require(to != address(0), "Inventory: transfer to zero");
        uint256 length = ids.length;
        require(length == values.length, "Inventory: inconsistent arrays");
        address sender = _msgSender();
        require(_isOperatable(from, sender), "Inventory: non-approved sender");

        uint256 nfCollectionId;
        uint256 nfCollectionCount;
        for (uint256 i; i < length; i++) {
            uint256 id = ids[i];
            uint256 value = values[i];
            if (isFungible(id)) {
                _transferFungible(from, to, id, value);
            } else if (id & _NF_TOKEN_MASK != 0) {
                _transferNFT(from, to, id, value, true);
                uint256 nextCollectionId = id & _NF_COLLECTION_MASK;
                if (nfCollectionId == 0) {
                    nfCollectionId = nextCollectionId;
                    nfCollectionCount = 1;
                } else {
                    if (nextCollectionId != nfCollectionId) {
                        _balances[nfCollectionId][from] -= nfCollectionCount;
                        _balances[nfCollectionId][to] += nfCollectionCount;
                        nfCollectionId = nextCollectionId;
                        nfCollectionCount = 1;
                    } else {
                        nfCollectionCount++;
                    }
                }
            } else {
                revert("Inventory: not a token id");
            }
        }

        if (nfCollectionId != 0) {
            _balances[nfCollectionId][from] -= nfCollectionCount;
            _balances[nfCollectionId][to] += nfCollectionCount;
        }

        emit TransferBatch(sender, from, to, ids, values);
        if (to.isContract()) {
            _callOnERC1155BatchReceived(from, to, ids, values, data);
        }
    }

    //============================== Minting Core Internal Helpers =================================/

    function _mintFungible(
        address to,
        uint256 id,
        uint256 value
    ) internal {
        require(value != 0, "Inventory: zero value");
        uint256 supply = _supplies[id];
        uint256 newSupply = supply + value;
        require(newSupply > supply, "Inventory: supply overflow");
        _supplies[id] = newSupply;
        // cannot overflow as any balance is bounded up by the supply which cannot overflow
        _balances[id][to] += value;
    }

    function _mintNFT(
        address to,
        uint256 id,
        uint256 value,
        bool isBatch
    ) internal {
        require(value == 1, "Inventory: wrong NFT value");
        require(_owners[id] == 0, "Inventory: existing/burnt NFT");

        _owners[id] = uint256(to);

        if (!isBatch) {
            uint256 collectionId = id & _NF_COLLECTION_MASK;
            // it is virtually impossible that a non-fungible collection supply
            // overflows due to the cost of minting individual tokens
            ++_supplies[collectionId];
            // cannot overflow as supply cannot overflow
            ++_balances[collectionId][to];
        }
    }

    //============================== Minting Internal Functions ====================================/

    /// @dev See {IERC1155InventoryMintable-safeMint(address,uint256,uint256,bytes)}.
    function _safeMint(
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) internal {
        require(to != address(0), "Inventory: transfer to zero");

        if (isFungible(id)) {
            _mintFungible(to, id, value);
        } else if (id & _NF_TOKEN_MASK != 0) {
            _mintNFT(to, id, value, false);
        } else {
            revert("Inventory: not a token id");
        }

        emit TransferSingle(_msgSender(), address(0), to, id, value);
        if (to.isContract()) {
            _callOnERC1155Received(address(0), to, id, value, data);
        }
    }

    /// @dev See {IERC1155InventoryMintable-safeBatchMint(address,uint256[],uint256[],bytes)}.
    function _safeBatchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "Inventory: transfer to zero");
        uint256 length = ids.length;
        require(length == values.length, "Inventory: inconsistent arrays");

        uint256 nfCollectionId;
        uint256 nfCollectionCount;
        for (uint256 i; i < length; i++) {
            uint256 id = ids[i];
            uint256 value = values[i];
            if (isFungible(id)) {
                _mintFungible(to, id, value);
            } else if (id & _NF_TOKEN_MASK != 0) {
                _mintNFT(to, id, value, true);
                uint256 nextCollectionId = id & _NF_COLLECTION_MASK;
                if (nfCollectionId == 0) {
                    nfCollectionId = nextCollectionId;
                    nfCollectionCount = 1;
                } else {
                    if (nextCollectionId != nfCollectionId) {
                        _balances[nfCollectionId][to] += nfCollectionCount;
                        _supplies[nfCollectionId] += nfCollectionCount;
                        nfCollectionId = nextCollectionId;
                        nfCollectionCount = 1;
                    } else {
                        nfCollectionCount++;
                    }
                }
            } else {
                revert("Inventory: not a token id");
            }
        }

        if (nfCollectionId != 0) {
            _balances[nfCollectionId][to] += nfCollectionCount;
            _supplies[nfCollectionId] += nfCollectionCount;
        }

        emit TransferBatch(_msgSender(), address(0), to, ids, values);
        if (to.isContract()) {
            _callOnERC1155BatchReceived(address(0), to, ids, values, data);
        }
    }

    //============================== Transfer Core Internal Helpers =================================/

    function _transferFungible(
        address from,
        address to,
        uint256 id,
        uint256 value
    ) internal {
        require(value != 0, "Inventory: zero value");
        uint256 balance = _balances[id][from];
        require(balance >= value, "Inventory: not enough balance");
        _balances[id][from] = balance - value;
        // cannot overflow as supply cannot overflow
        _balances[id][to] += value;
    }

    function _transferNFT(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bool isBatch
    ) internal {
        require(value == 1, "Inventory: wrong NFT value");
        require(from == address(_owners[id]), "Inventory: non-owned NFT");
        _owners[id] = uint256(to);
        if (!isBatch) {
            uint256 collectionId = id & _NF_COLLECTION_MASK;
            // cannot underflow as balance is verified through ownership
            _balances[collectionId][from] -= 1;
            // cannot overflow as supply cannot overflow
            _balances[collectionId][to] += 1;
        }
    }
}
