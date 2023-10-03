// Sources flattened with hardhat v2.16.1 https://hardhat.org

// File contracts/openzeppelin/utils/Context.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.21;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


// File contracts/openzeppelin/access/Ownable.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.21;
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File contracts/FUSDTokenUtils/FlaggingMinters.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
abstract contract FlaggingMinters is Ownable {
    mapping(address => bool) private _isMinter;

    constructor() {
        setIsMinter(_msgSender(), true);
    }

    modifier onlyMinters() {
        require(_isMinter[_msgSender()], "FlaggingMinters: caller is not a minter");
        _;
    }

    /**
     * @dev Overrides the transferOwnership function to set the new owner as a minter.
     */
    function transferOwnership(address newOwner) public override virtual onlyOwner {
        setIsMinter(newOwner, true);
        super.transferOwnership(newOwner);
    }

    /**
     * @dev Allows the owner to change the status of a minter.
     * @param minter Address of the minter to change status.
     * @param value True for minter, false for non-minter.
     */
    function setIsMinter(address minter, bool value) public onlyOwner {
        _isMinter[minter] = value;
    }

    /**
     * @dev Returns true if the address is a minter.
     * @param minter Address to check.
     */
    function isMinter(address minter) external view returns (bool) {
        return _isMinter[minter];
    }
}


// File contracts/openzeppelin/interfaces/draft-IERC6093.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @dev Standard ERC20 Errors
 * Interface of the ERC6093 custom errors for ERC20 tokens
 * as defined in https://eips.ethereum.org/EIPS/eip-6093
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the ERC6093 custom errors for ERC721 tokens
 * as defined in https://eips.ethereum.org/EIPS/eip-6093
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the ERC6093 custom errors for ERC1155 tokens
 * as defined in https://eips.ethereum.org/EIPS/eip-6093
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}


// File contracts/openzeppelin/token/ERC20/IERC20.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.21;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}


// File contracts/openzeppelin/token/ERC20/extensions/IERC20Metadata.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.21;

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// File contracts/openzeppelin/token/ERC20/ERC20.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.21;




/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error ERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `requestedDecrease`.
     */
    function decreaseAllowance(address spender, uint256 requestedDecrease) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < requestedDecrease) {
            revert ERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
        }
        unchecked {
            _approve(owner, spender, currentAllowance - requestedDecrease);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, amount);
    }

    /**
     * @dev Transfers `amount` of tokens from `from` to `to`, or alternatively mints (or burns) if `from` (or `to`) is
     * the zero address. All customizations to transfers, mints, and burns should be done by overriding this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 amount) internal virtual {
        if (from == address(0)) {
            _totalSupply += amount;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < amount) {
                revert ERC20InsufficientBalance(from, fromBalance, amount);
            }
            unchecked {
                // Overflow not possible: amount <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - amount;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: amount <= totalSupply or amount <= fromBalance <= totalSupply.
                _totalSupply -= amount;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + amount is at most totalSupply, which we know fits into a uint256.
                _balances[to] += amount;
            }
        }

        emit Transfer(from, to, amount);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 amount) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, by transferring it to address(0).
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        _approve(owner, spender, amount, true);
    }

    /**
     * @dev Alternative version of {_approve} with an optional flag that can enable or disable the Approval event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to true
     * using the following override:
     * ```
     * function _approve(address owner, address spender, uint256 amount, bool) internal virtual override {
     *     super._approve(owner, spender, amount, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 amount, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = amount;
        if (emitEvent) {
            emit Approval(owner, spender, amount);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - amount, false);
            }
        }
    }
}


// File contracts/FUSDToken.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;


contract FUSDToken is ERC20, FlaggingMinters {
    constructor() ERC20("FUSD Token", "FUSD") Ownable(_msgSender()) {}

    function mint(address _to, uint256 _amount) external onlyMinters {
        _mint(_to, _amount);
    }
}


// File contracts/libraries/ERC20Utils.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
library ERC20Utils {
    /**
     * @dev Returns the token key by hashing the token symbol.
     */
    function getTokenKey(address token) internal view returns (bytes32) {
        return keccak256(bytes(ERC20(token).symbol()));
    }
}


// File contracts/TokenAdapterUtils/TokenAdapterInterface.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface TokenAdapterInterface {
    function decimals() external view returns (uint8);

    function getOracle() external view returns (address);

    function getToken() external view returns (address);

    function getOracleValue() external view returns (uint128);
}


// File contracts/FUSDTokenSaleUtils/TokenAdapterFactory.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
abstract contract TokenAdapterFactory is Ownable {
    mapping(bytes32 => TokenAdapterInterface) private tokenAdapters;
    bytes32[] private tokenKeys;

    modifier tokenAdapterExists(address token) {
        bytes32 tokenKey = ERC20Utils.getTokenKey(token);

        require(
            address(tokenAdapters[tokenKey]) != address(0) && tokenAdapters[tokenKey].getToken() == token,
            "Token adapter does not exist"
        );
        _;
    }

    function getTokenKeys() internal view returns (bytes32[] memory) {
        return tokenKeys;
    }

    function getTokenAdapters() internal view returns (TokenAdapterInterface[] memory) {
        TokenAdapterInterface[] memory adapters = new TokenAdapterInterface[](tokenKeys.length);
        for (uint256 i = 0; i < tokenKeys.length; i++) {
            adapters[i] = tokenAdapters[tokenKeys[i]];
        }

        return adapters;
    }

    function getOracleValue(address token) internal view tokenAdapterExists(token) returns (uint128) {
        return tokenAdapters[ERC20Utils.getTokenKey(token)].getOracleValue();
    }

    function getOracleDecimals(address token) internal view returns (uint8) {
        return tokenAdapters[ERC20Utils.getTokenKey(token)].decimals();
    }

    /**
     * @dev Allows the owner to add a new token adapter.
     * There can be only one adapter per token symbol.
     * @param tokenAdapter Address of the token adapter
     */
    function addTokenAdapter(address tokenAdapter) external onlyOwner {
        TokenAdapterInterface tokenAdapterInstance = TokenAdapterInterface(tokenAdapter);
        bytes32 tokenKey = ERC20Utils.getTokenKey(tokenAdapterInstance.getToken());
        require(address(tokenAdapters[tokenKey]) == address(0), "Token adapter already exists");

        tokenAdapters[tokenKey] = tokenAdapterInstance;
        tokenKeys.push(tokenKey);
    }

    /**
     * @dev Returns addresses of all registered token adapters.
     */
    function getTokenAdapterAddresses() external view returns (address[] memory) {
        address[] memory adapters = new address[](tokenKeys.length);
        for (uint256 i = 0; i < tokenKeys.length; i++) {
            adapters[i] = address(tokenAdapters[tokenKeys[i]]);
        }

        return adapters;
    }

    /**
     * @dev Returns symbols of all registered tokens.
     */
    function getTokenSymbols() external view returns (string[] memory) {
        string[] memory symbols = new string[](tokenKeys.length);
        for (uint256 i = 0; i < tokenKeys.length; i++) {
            symbols[i] = ERC20(tokenAdapters[tokenKeys[i]].getToken()).symbol();
        }

        return symbols;
    }
}


// File contracts/FUSDTokenSaleUtils/ERC20ExchangeVault.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
abstract contract ERC20ExchangeVault is TokenAdapterFactory {
    mapping(address => mapping(bytes32 => uint256)) private userTokenBalances;

    function _depositToken(
        address user,
        address token,
        uint256 amount
    ) internal tokenAdapterExists(token) {
        userTokenBalances[user][ERC20Utils.getTokenKey(token)] += amount;
        ERC20(token).transferFrom(_msgSender(), address(this), amount);
    }

    function _withdrawToken(
        address user,
        address token,
        uint256 amount
    ) internal tokenAdapterExists(token) {
        bytes32 tokenKey = ERC20Utils.getTokenKey(token);
        require(userTokenBalances[user][tokenKey] >= amount, "ERC20ExchangeVault: insufficient balance");

        userTokenBalances[user][tokenKey] -= amount;
        ERC20(token).transfer(user, amount);
    }

    /**
     * @dev Returns the balance of the user for the specified token. Must provide a token with a valid adapter.
     * @param user Address of the user
     * @param token Address of the token. Must have a valid adapter.
     */
    function getUserTokenBalance(address user, address token) public view tokenAdapterExists(token) returns (uint256) {
        return userTokenBalances[user][ERC20Utils.getTokenKey(token)];
    }

    /**
     * @dev Returns the balances of the user for all tokens.
     * @param user Address of the user
     * @return balances Array of balances. The index of each balance corresponds to the index of the symbol in the symbols array.
     * @return symbols Array of symbols. The index of each symbol corresponds to the index of the balance in the balances array.
     */
    function getUserTokenBalances(address user) public view returns (uint256[] memory, string[] memory) {
        TokenAdapterInterface[] memory tokenAdapters = getTokenAdapters();
        bytes32[] memory tokenKeys = getTokenKeys();

        uint256[] memory balances = new uint256[](tokenKeys.length);
        string[] memory symbols = new string[](tokenKeys.length);

        for (uint256 i = 0; i < tokenKeys.length; i++) {
            balances[i] = userTokenBalances[user][tokenKeys[i]];
            symbols[i] = ERC20(tokenAdapters[i].getToken()).symbol();
        }

        return (balances, symbols);
    }

    function withdrawAllUserAssetsToWithdrawable(address user, address withrawable) internal {
        TokenAdapterInterface[] memory tokenAdapters = getTokenAdapters();
        bytes32[] memory tokenKeys = getTokenKeys();

        for (uint256 i = 0; i < tokenKeys.length; i++) {
            uint256 tokenBalance = userTokenBalances[user][tokenKeys[i]];
            ERC20 token = ERC20(tokenAdapters[i].getToken());

            if (tokenBalance > 0) {
                token.transfer(withrawable, tokenBalance);
                userTokenBalances[user][tokenKeys[i]] = 0;
            }
        }
    }
}


// File contracts/libraries/Math.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

library Math {
    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x <= y ? x : y;
    }

    /**
     * @dev Multiplies n by 10^exponent. Exponent can be negative, in which case it will divide n
     * by 10^|exponent|.
     */
    function multiplyByTenPow(uint256 n, int256 exponent) internal pure returns (uint256) {
        uint256 absoluteExponent = abs(exponent);
        if (exponent < 0) {
            return n / 10**absoluteExponent;
        }

        return n * 10**absoluteExponent;
    }
}


// File contracts/libraries/TransformUintToInt.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

library TransformUintToInt {
    function toInt(uint8 x) internal pure returns (int16) {
        return int16(uint16(x));
    }
}


// File contracts/FUSDTokenSaleUtils/FUSDTokenHandler.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
abstract contract FUSDTokenHandler is ERC20ExchangeVault {
    using TransformUintToInt for uint8;

    FUSDToken private fusdToken;

    constructor(address _fusdToken) {
        fusdToken = FUSDToken(_fusdToken);
    }

    /**
     * @dev Returns the address of the FUSD token.
     */
    function getFUSDToken() public view returns (address) {
        return address(fusdToken);
    }

    function mintFUSD(address user, uint256 amount) internal {
        fusdToken.mint(user, amount);
    }

    function transferFUSD(
        address from,
        address to,
        uint256 amount
    ) internal {
        fusdToken.transferFrom(from, to, amount);
    }

    /**
     * @dev Calculates the price of the token in FUSD.
     * Must provide a token with a valid adapter, otherwise reverts.
     * @param token Address of the token. Must have a valid adapter.
     * @param amount Amount of the token
     */
    function tokenPriceInFUSD(address token, uint256 amount) public view returns (uint256) {
        uint128 priceInUsd = getOracleValue(token);
        int16 usdPriceDecimals = getOracleDecimals(token).toInt();
        int16 tokenDecimals = ERC20(token).decimals().toInt();
        int16 fusdDecimals = fusdToken.decimals().toInt();

        return Math.multiplyByTenPow(amount * priceInUsd, fusdDecimals - usdPriceDecimals - tokenDecimals);
    }

    /**
     * @dev Returns the total worth of all collateral tokens currently deposited by the user
     * in FUSD. The worth of each token is calculated using the token's price in FUSD.
     * @param user Address of the user to calculate the collateral worth for
     */
    function getUserCollateralWorthInFUSD(address user) public view returns (uint256) {
        TokenAdapterInterface[] memory tokenAdapters = getTokenAdapters();
        bytes32[] memory tokenKeys = getTokenKeys();

        uint256 collateralWorth = 0;

        for (uint256 i = 0; i < tokenKeys.length; i++) {
            address tokenAddress = tokenAdapters[i].getToken();
            uint256 tokenBalance = getUserTokenBalance(user, tokenAddress);
            if (tokenBalance > 0) {
                collateralWorth += tokenPriceInFUSD(tokenAddress, tokenBalance);
            }
        }

        return collateralWorth;
    }
}


// File contracts/FUSDTokenSaleUtils/InterestCalculator.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

abstract contract InterestCalculator {
    // Each point of annualInterestRateTenthPercent represents 0.1% of annual interest rate.
    uint16 private annualInterestRateTenthPerc;
    uint16 private constant MAX_INTEREST_RATE = 1000;

    constructor(uint16 _annualInterestRateTenthPerc) validAnnualInterestRate(_annualInterestRateTenthPerc) {
        annualInterestRateTenthPerc = _annualInterestRateTenthPerc;
    }

    modifier validAnnualInterestRate(uint16 _annualInterestRateTenthPerc) {
        require(
            0 <= _annualInterestRateTenthPerc && _annualInterestRateTenthPerc <= MAX_INTEREST_RATE,
            "InterestCalculator: Invalid annual interest rate"
        );
        _;
    }

    function getAnnualInterestRateTenthPerc() public view returns (uint16) {
        return annualInterestRateTenthPerc;
    }

    function setAnnualInterestRateTenthPerc(uint16 _annualInterestRateTenthPerc)
        public
        virtual
        validAnnualInterestRate(_annualInterestRateTenthPerc)
    {
        annualInterestRateTenthPerc = _annualInterestRateTenthPerc;
    }

    function calculateInterest(
        uint256 amount,
        uint256 loanedAt,
        uint256 currentTimestamp
    ) internal view returns (uint256) {
        uint256 timeDiff = currentTimestamp - loanedAt;
        return (amount * timeDiff * annualInterestRateTenthPerc) / (1000 * 365 days);
    }
}


// File contracts/FUSDTokenSaleUtils/CollateralRatioCalculator.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

abstract contract CollateralRatioCalculator {
    uint256 private minCollateralRatioForLoanTenthPerc;
    uint256 private liquidationPenaltyTenthPerc;

    constructor(uint256 _minCollateralRatioForLoanTenthPerc, uint256 _liquidationPenaltyTenthPerc) {
        minCollateralRatioForLoanTenthPerc = _minCollateralRatioForLoanTenthPerc;
        liquidationPenaltyTenthPerc = _liquidationPenaltyTenthPerc;
    }

    /**
     * @dev Returns the minimum collateral ratio required for a loan in 0.1%.
     * The user must have at least this much collateral to borrow FUSD. Also the
     * user's collateral ratio must be at least this much after borrowing FUSD.
     */
    function getMinCollateralRatioForLoanTenthPerc() public view returns (uint256) {
        return minCollateralRatioForLoanTenthPerc;
    }

    function setMinCollateralRatioForLoanTenthPerc(uint256 _minCollateralRatioForLoanTenthPerc) public virtual {
        minCollateralRatioForLoanTenthPerc = _minCollateralRatioForLoanTenthPerc;
    }

    /**
     * @dev Returns the liquidation penalty in 0.1%. The liquidation penalty
     * is used to calculate the liquidation threshold
     */
    function getLiquidationPenaltyTenthPerc() public view returns (uint256) {
        return liquidationPenaltyTenthPerc;
    }

    function setLiquidationPenaltyTenthPerc(uint256 _liquidationPenaltyTenthPerc) public virtual {
        liquidationPenaltyTenthPerc = _liquidationPenaltyTenthPerc;
    }

    /**
     * @dev Returns the collateral ratio in 0.1%.
     */
    function calculateCollateralRatio(uint256 collateralWorthInFUSD, uint256 totalDebt)
        internal
        pure
        returns (uint256)
    {
        require(totalDebt > 0, "CollateralRatioCalculator: Total debt must be greater than 0");

        return (collateralWorthInFUSD * 1000) / totalDebt;
    }

    /**
     * @dev Checks if the collateral ratio is safe for a loan. If the function returns false,
     * the user should not be allowed to borrow FUSD.
     */
    function isCollateralRatioSafe(uint256 collateralWorthInFUSD, uint256 totalDebt) internal view returns (bool) {
        if (totalDebt == 0) return true;
        return calculateCollateralRatio(collateralWorthInFUSD, totalDebt) >= minCollateralRatioForLoanTenthPerc;
    }

    function getLiquidationThreshold() public view virtual returns (uint256) {
        return 1000 + liquidationPenaltyTenthPerc;
    }
}


// File contracts/FUSDTokenSaleUtils/TimeHandler.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

abstract contract TimeHandler {
    function time() internal view returns (uint256) {
        return block.timestamp;
    }
}


// File contracts/FUSDTokenSaleUtils/DebtHandler.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;


abstract contract DebtHandler is InterestCalculator, TimeHandler {
    enum DebtAction {
        Loan,
        Repayment
    }

    struct DebtChange {
        uint256 amount;
        DebtAction action;
        uint256 timestamp;
    }

    // user => debt session => debt changes
    mapping(address => DebtChange[][]) private debtChanges;

    /**
     * The maximum number of debt changes per debt session. This is to prevent
     * users from racking up too many debt changes in a single session. To
     * process a debt repayment, we have to calculate the current debt of the user,
     * which means we have to iterate over all current debt changes. This can be
     * expensive if the number of debt changes is very high. If the cost
     * becomes too high, there is a chance that the transaction will run out of
     * gas and fail.
     *
     * Here is some data from testing the gas cost of processing a debt repayment
     * through the `payOffAllDebt` function in the `FUSDTokenSale` contract. We
     * tested the gas cost for different numbers of debt changes. For every 2 debt
     * changes, one is a loan and the other is a repayment:
     *
     * Number of debt changes | Gas cost in units
     * -----------------------|---------
     * 10                     |  258,043
     * 50                     |  707,560
     * 100                    |  1,270,017
     * 250                    |  2,961,141
     * 500                    |  5,792,180
     * 1000                   |  11,501,133
     */
    uint256 private constant DEBT_CHANGES_LIMIT = 400;

    modifier belowDebtChangesLimit(address user) {
        require(getNumOfCurrentDebtChanges(user) < DEBT_CHANGES_LIMIT, "DebtHandler: Debt changes limit reached");
        _;
    }

    function addNewDebtChange(address user, DebtChange memory change) private {
        uint256 lastChangeIndex = debtChanges[user].length - 1;
        debtChanges[user][lastChangeIndex].push(change);
    }

    function _addLoan(
        address user,
        uint256 amount,
        uint256 timestamp
    ) internal {
        addNewDebtChange(user, DebtChange(amount, DebtAction.Loan, timestamp));
    }

    function _addRepayment(
        address user,
        uint256 amount,
        uint256 timestamp
    ) internal {
        addNewDebtChange(user, DebtChange(amount, DebtAction.Repayment, timestamp));
    }

    function _addNewDebtSession(address user) internal {
        debtChanges[user].push();
    }

    /**
     * @dev Returns all debt changes for a user. This includes debt changes from
     * previous sessions. The debt changes are sorted by timestamp. The change
     * can either be a loan or a repayment.
     */
    function getAllDebtChanges(address user) external view returns (DebtChange[][] memory) {
        return debtChanges[user];
    }

    /**
     * @dev Returns the debt changes for a user from the most recent session.
     * If the user has previously build up debt and repaid it in full afterwards,
     * changes from that period up until the point the debt was repaid will not be
     * returned by this function. The debt changes are sorted by timestamp.
     * The change can either be a loan or a repayment.
     */
    function getCurrentDebtChanges(address user) public view returns (DebtChange[] memory) {
        if (debtChanges[user].length == 0) {
            return new DebtChange[](0);
        }
        uint256 lastChangeIndex = debtChanges[user].length - 1;
        return debtChanges[user][lastChangeIndex];
    }

    /**
     * @dev Returns the number of debt changes for a user from the most recent session.
     */
    function getNumOfCurrentDebtChanges(address user) public view returns (uint256) {
        return getCurrentDebtChanges(user).length;
    }

    /**
     * @dev Returns the base debt and interest for a user. The base debt is the amount
     * of FUSD borrowed by the user. Interest is accrued each second on the base debt.
     * Each repayment lowers the interest first and then the base debt.
     */
    function calculateBaseDebtAndInterest(address user) public view returns (uint256, uint256) {
        DebtChange[] memory changes = getCurrentDebtChanges(user);
        uint256 baseDebt = 0;
        uint256 totalInterest = 0;
        uint256 lastChangeAt;

        for (uint256 i = 0; i < changes.length; i++) {
            DebtChange memory change = changes[i];

            if (baseDebt > 0) {
                totalInterest += calculateInterest(baseDebt, lastChangeAt, change.timestamp);
            }

            lastChangeAt = change.timestamp;

            if (change.action == DebtAction.Loan) {
                baseDebt += change.amount;
            } else if (change.action == DebtAction.Repayment) {
                uint256 amountToDeduct = change.amount;

                if (amountToDeduct >= totalInterest) {
                    amountToDeduct -= totalInterest;
                    totalInterest = 0;
                } else if (totalInterest > 0) {
                    totalInterest -= amountToDeduct;
                    amountToDeduct = 0;
                }

                baseDebt -= amountToDeduct;
            }
        }

        if (baseDebt > 0) {
            totalInterest += calculateInterest(baseDebt, lastChangeAt, time());
        }

        return (baseDebt, totalInterest);
    }

    /**
     * @dev Returns the total debt for a user. The total debt is the sum of the base debt
     * and the interest.
     */
    function getTotalDebt(address user) public view returns (uint256) {
        (uint256 base, uint256 interest) = calculateBaseDebtAndInterest(user);
        return base + interest;
    }
}


// File contracts/FUSDTokenSaleUtils/LiquidatingUserAssetsBelowLiquidationThreshold.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;


abstract contract LiquidatingUserAssetsBelowLiquidationThreshold is DebtHandler, CollateralRatioCalculator, Ownable {
    mapping(address => bool) private debtorRegistered;
    address[] private debtors;

    /**
     * @dev Returns the liquidation threshold in percentage. If the collateral ratio
     * of a user is below this threshold, the user will be liquidated.
     * @return {uint256} liquidation threshold in percentage in 0.1%.
     */
    function getLiquidationThreshold() public view override returns (uint256) {
        return super.getLiquidationThreshold() + getAnnualInterestRateTenthPerc();
    }

    function registerDebtor(address debtor) internal {
        if (debtorRegistered[debtor]) return;

        debtors.push(debtor);
        debtorRegistered[debtor] = true;
        _addNewDebtSession(debtor);
    }

    /**
     * @dev Returns all users who have ever borrowed FUSD at some point.
     */
    function getAllDebtors() public view returns (address[] memory) {
        return debtors;
    }

    /**
     * @dev Returns all users who have outstanding debt.
     */
    function getCurrentDebtors() external view returns (address[] memory) {
        address[] memory allDebtors = getAllDebtors();
        address[] memory currentDebtors = new address[](allDebtors.length);
        uint256 currentDebtorsCount = 0;
        for (uint256 i = 0; i < allDebtors.length; i++) {
            address debtor = allDebtors[i];
            if (getTotalDebt(debtor) > 0) {
                currentDebtors[currentDebtorsCount] = debtor;
                currentDebtorsCount++;
            }
        }

        assembly {
            mstore(currentDebtors, currentDebtorsCount)
        }

        return currentDebtors;
    }

    /**
     * @dev Returns all users who have outstanding debt and are below the liquidation threshold.
     * All users who are below the liquidation threshold will be liquidated.
     */
    function getDebtorsBelowLiquidationThreshold() external view returns (address[] memory) {
        address[] memory allDebtors = getAllDebtors();
        address[] memory debtorsBelowLiquidationThreshold = new address[](allDebtors.length);
        uint256 debtorsBelowLiquidationThresholdCount = 0;
        for (uint256 i = 0; i < allDebtors.length; i++) {
            address debtor = allDebtors[i];
            if (isDebtorBelowLiquidationThreshold(debtor)) {
                debtorsBelowLiquidationThreshold[debtorsBelowLiquidationThresholdCount] = debtor;
                debtorsBelowLiquidationThresholdCount++;
            }
        }

        assembly {
            mstore(debtorsBelowLiquidationThreshold, debtorsBelowLiquidationThresholdCount)
        }

        return debtorsBelowLiquidationThreshold;
    }

    function isDebtorBelowLiquidationThreshold(address debtor) public view virtual returns (bool);
}


// File contracts/FUSDTokenSaleUtils/StoringERC20WithdrawableAddress.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

abstract contract StoringERC20WithdrawableAddress is Ownable {
    address private erc20WithdrawableAddress;

    constructor(address _erc20WithdrawableAddress) {
        erc20WithdrawableAddress = _erc20WithdrawableAddress;
    }

    /**
     * @dev Returns the address to which the owner can withdraw
     * liquidated user collateral assets.
     */
    function getERC20WithdrawableAddress() public view returns (address) {
        return erc20WithdrawableAddress;
    }

    /**
     * @dev Allows the owner to set the withdrawal address.
     */
    function setERC20WithdrawableAddress(address _erc20WithdrawableAddress) external onlyOwner {
        erc20WithdrawableAddress = _erc20WithdrawableAddress;
    }
}


// File contracts/FUSDTokenSale.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
contract FUSDTokenSale is
    FUSDTokenHandler,
    LiquidatingUserAssetsBelowLiquidationThreshold,
    StoringERC20WithdrawableAddress
{
    using TransformUintToInt for uint8;

    event LiquidatedUser(address indexed user, uint256 collateralWorthInFUSD, uint256 totalDebt);

    constructor(
        address _fusdToken,
        uint16 annualInterestRateTenthPerc,
        uint256 minCollateralRatioForLoanTenthPerc,
        uint256 liquidationPenaltyTenthPerc,
        address erc20WithdrawableAddress
    )
        FUSDTokenHandler(_fusdToken)
        InterestCalculator(annualInterestRateTenthPerc)
        CollateralRatioCalculator(minCollateralRatioForLoanTenthPerc, liquidationPenaltyTenthPerc)
        StoringERC20WithdrawableAddress(erc20WithdrawableAddress)
        Ownable(_msgSender())
        LTIsBelowMinCR(annualInterestRateTenthPerc, liquidationPenaltyTenthPerc, minCollateralRatioForLoanTenthPerc)
    {}

    modifier LTIsBelowMinCR(
        uint256 annualInterestRateTenthPerc,
        uint256 liquidationPenaltyTenthPerc,
        uint256 minCollateralRatioForLoanTenthPerc
    ) {
        require(
            1000 + liquidationPenaltyTenthPerc + annualInterestRateTenthPerc < minCollateralRatioForLoanTenthPerc,
            "FUSDTokenSale: Liquidation threshold must be below minimum collateral ratio"
        );
        _;
    }

    modifier collateralRatioSafe(address user) {
        _;
        require(
            isCollateralRatioSafe(getUserCollateralWorthInFUSD(user), getTotalDebt(user)),
            "FUSDTokenSale: collateral ratio is unsafe"
        );
    }

    function depositTokenAndBorrowFUSD(
        address token,
        uint256 amount,
        uint256 loanAmount
    ) external {
        depositToken(token, amount);
        borrowFUSD(loanAmount);
    }

    /**
     * @dev Allows the user to borrow FUSD. The user must have enough collateral
     * to borrow FUSD. The collateral ratio must be safe after borrowing FUSD, otherwise
     * the transaction reverts.
     * @param amount Amount of FUSD to borrow
     */
    function borrowFUSD(uint256 amount) public collateralRatioSafe(_msgSender()) belowDebtChangesLimit(_msgSender()) {
        address user = _msgSender();

        registerDebtor(user);
        _addLoan(user, amount, time());
        mintFUSD(user, amount);
    }

    /**
     * @dev Allows the user to repay FUSD. The user must have enough FUSD balance
     * and allowance to repay FUSD.
     * @param amount Amount of FUSD to repay
     */
    function payOffDebt(uint256 amount) public belowDebtChangesLimit(_msgSender()) {
        address user = _msgSender();
        uint256 totalDebt = getTotalDebt(user);

        require(0 < amount, "FUSDTokenSale: amount must be greater than 0");
        require(amount <= totalDebt, "FUSDTokenSale: amount exceeds total debt");

        _addRepayment(user, amount, time());
        if (amount == totalDebt) _addNewDebtSession(user);

        transferFUSD(user, getERC20WithdrawableAddress(), amount);
    }

    /**
     * @dev Allows the user to repay all FUSD debt. The user must have enough FUSD balance
     * and allowance to repay FUSD.
     */
    function payOffAllDebt() external {
        payOffDebt(getTotalDebt(_msgSender()));
    }

    /**
     * @dev Allows the user to deposit tokens as collateral. The user must have enough
     * token balance and allowance to deposit tokens. The token must have a valid
     * adapter, otherwise the transaction reverts.
     * @param token Address of the token to deposit
     * @param amount Amount of the token to deposit
     */
    function depositToken(address token, uint256 amount) public {
        _depositToken(_msgSender(), token, amount);
    }

    /**
     * @dev Allows the user to withdraw tokens. The user must have sufficient collateral
     * ratio after the transaction for the withdrawal to go through.
     * The token must have a valid adapter, otherwise the transaction reverts.
     * @param token Address of the token to withdraw
     * @param amount Amount of the token to withdraw
     */
    function withdrawToken(address token, uint256 amount) external collateralRatioSafe(_msgSender()) {
        _withdrawToken(_msgSender(), token, amount);
    }

    /**
     * @dev Returns the collateral ratio for a user in percentage. The collateral ratio
     * is calculated using the total worth of the user's collateral in FUSD and the
     * total debt in FUSD. Then the collateral worth is divided by the total debt
     */
    function getCollateralRatio(address user) external view returns (uint256) {
        return calculateCollateralRatio(getUserCollateralWorthInFUSD(user), getTotalDebt(user));
    }

    /**
     * @dev Returns true if the user's collateral ratio is below the liquidation threshold.
     * This function must return true for a user to be liquidated.
     * @param debtor Address of the user
     */
    function isDebtorBelowLiquidationThreshold(address debtor) public view override returns (bool) {
        uint256 totalDebt = getTotalDebt(debtor);
        if (totalDebt == 0) return false;

        uint256 collateralWorthInFUSD = getUserCollateralWorthInFUSD(debtor);
        return calculateCollateralRatio(collateralWorthInFUSD, totalDebt) < getLiquidationThreshold();
    }

    /**
     * @dev Liquidates user. Sends all user collateral assets to the ERC20WithdrawableAddress,
     * erases the user's debt and starts a new debt session. A liquidation event is emitted.
     * @param user Address of the user
     */
    function liquidateUser(address user) external {
        require(isDebtorBelowLiquidationThreshold(user), "FUSDTokenSale: user is not below liquidation threshold");

        address erc20WithdrawableAddress = getERC20WithdrawableAddress();
        uint256 totalDebt = getTotalDebt(user);

        emit LiquidatedUser(user, getUserCollateralWorthInFUSD(user), totalDebt);

        withdrawAllUserAssetsToWithdrawable(user, erc20WithdrawableAddress);
        _addRepayment(user, totalDebt, time());
        _addNewDebtSession(user);
    }

    /**
     * @dev Allows owner to set the minimum collateral ratio required for a loan in 0.1%.
     * The minimum collateral ratio must be below the liquidation threshold.
     */
    function setMinCollateralRatioForLoanTenthPerc(uint256 _minCollateralRatioForLoanTenthPerc)
        public
        override
        onlyOwner
        LTIsBelowMinCR(
            getAnnualInterestRateTenthPerc(),
            getLiquidationPenaltyTenthPerc(),
            _minCollateralRatioForLoanTenthPerc
        )
    {
        super.setMinCollateralRatioForLoanTenthPerc(_minCollateralRatioForLoanTenthPerc);
    }

    /**
     * @dev Allows owner to set the liquidation penalty in 0.1%.
     * The resulting liquidation penalty must be below the minimum collateral ratio.
     */
    function setLiquidationPenaltyTenthPerc(uint256 _liquidationPenaltyTenthPerc)
        public
        override
        onlyOwner
        LTIsBelowMinCR(
            getAnnualInterestRateTenthPerc(),
            _liquidationPenaltyTenthPerc,
            getMinCollateralRatioForLoanTenthPerc()
        )
    {
        super.setLiquidationPenaltyTenthPerc(_liquidationPenaltyTenthPerc);
    }

    /**
     * @dev Allows the owner to set the annual interest rate.
     * Each point of annualInterestRateTenthPercent represents 0.1% of annual interest rate.
     * The resulting liquidation penalty must be below the minimum collateral ratio.
     * @param _annualInterestRateTenthPerc Annual interest rate in tenth percent. Must be between 0 and 1000 (0% and 100.0%).
     */
    function setAnnualInterestRateTenthPerc(uint16 _annualInterestRateTenthPerc)
        public
        override
        onlyOwner
        LTIsBelowMinCR(
            _annualInterestRateTenthPerc,
            getLiquidationPenaltyTenthPerc(),
            getMinCollateralRatioForLoanTenthPerc()
        )
    {
        super.setAnnualInterestRateTenthPerc(_annualInterestRateTenthPerc);
    }

    /**
     * @dev Returns the maximum amount of FUSD the user can borrow. If the user falls
     * below the minimum collateral ratio, returns 0.
     * @param user Address of the user
     */
    function calculateMaxFUSDToBorrow(address user) external view returns (uint256) {
        uint256 collateralWorthInFUSD = getUserCollateralWorthInFUSD(user);
        uint256 totalDebt = getTotalDebt(user);
        uint256 minCollateralRatio = getMinCollateralRatioForLoanTenthPerc();

        uint256 totalAllowedToBorrow = (collateralWorthInFUSD * 1000) / minCollateralRatio;

        if (totalAllowedToBorrow <= totalDebt) return 0;

        return totalAllowedToBorrow - totalDebt;
    }

    /**
     * @dev Returns the maximum amount of collateral the user can withdraw. If the user falls
     * below the minimum collateral ratio, returns 0.
     * @param user Address of the user
     */
    function calculateMaxCollateralToWithdraw(address user) public view returns (uint256) {
        uint256 collateralWorthInFUSD = getUserCollateralWorthInFUSD(user);
        uint256 totalDebt = getTotalDebt(user);
        uint256 minCollateralRatio = getMinCollateralRatioForLoanTenthPerc();

        uint256 totalAllowedToWithdraw = (totalDebt * minCollateralRatio) / 1000;

        if (totalAllowedToWithdraw >= collateralWorthInFUSD) return 0;

        return collateralWorthInFUSD - totalAllowedToWithdraw;
    }

    /**
     * @dev Returns the maximum amount of tokens the user can withdraw. If the user falls
     * below the minimum collateral ratio, returns 0. If the total withdrawable collateral
     * amount is higher than the balance of an individual token, returns the balance of that token.
     * @param user Address of the user
     *
     * @return maxTokensToWithdraw Array of maximum tokens to withdraw. The index of each token corresponds to the index of the symbol in the symbols array.
     * @return symbols Array of symbols. The index of each symbol corresponds to the index of the token in the maxTokensToWithdraw array.
     */
    function calculateMaxTokensToWithdraw(address user)
        external
        view
        returns (uint256[] memory maxTokensToWithdraw, string[] memory symbols)
    {
        TokenAdapterInterface[] memory tokenAdapters = getTokenAdapters();
        bytes32[] memory tokenKeys = getTokenKeys();
        (uint256[] memory balances, ) = getUserTokenBalances(user);

        maxTokensToWithdraw = new uint256[](tokenKeys.length);
        symbols = new string[](tokenKeys.length);

        uint256 maxCollateralToWithdraw = calculateMaxCollateralToWithdraw(user);

        for (uint256 i = 0; i < tokenKeys.length; i++) {
            ERC20 token = ERC20(tokenAdapters[i].getToken());
            FUSDToken fusdToken = FUSDToken(getFUSDToken());
            uint128 priceInUsd = tokenAdapters[i].getOracleValue();

            int16 usdPriceDecimals = tokenAdapters[i].decimals().toInt();
            int16 tokenDecimals = ERC20(token).decimals().toInt();
            int16 fusdDecimals = fusdToken.decimals().toInt();

            uint256 tokensToWithdraw = Math.multiplyByTenPow(
                maxCollateralToWithdraw,
                tokenDecimals + usdPriceDecimals - fusdDecimals
            ) / priceInUsd;
            uint256 tokenBalance = balances[i];

            maxTokensToWithdraw[i] = Math.min(tokensToWithdraw, tokenBalance);
            symbols[i] = ERC20(tokenAdapters[i].getToken()).symbol();
        }
    }
}
