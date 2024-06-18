// SPDX-License-Identifier: MIT

/**
 * - FID20 - Version v1.0 - Developed by Apex777.eth
 *
 * @dev Modified verion of OpenZepplins ERC20 v5.0.0 to check if an address is
 * associated with an Farcaster Account through HAM L3's Onchain Farcaster data.
 *
 *
 * Changes for FID20
 * ----------------------
 *
 *  --- Variables ---
 *
 * - Add a new instance of the FIDStorage
 *
 * - Create an allowlist mapping to store addresses that won't have a Farcaster account
 *   but need access to tokens, pools, smart contracts, uniswap routers etc...
 *
 * - Custom error for invalid transfers not allowlisted or Farcaster accounts
 *
 *
 *  --- Functions ---
 *
 *  - isFIDWallet    - Public function to check if a wallet is a Farcaster account
 *
 *  - isAllowlisted  - Public function to check if a wallet is on the allowlist
 *
 *  - _allowTransfer - Internal function using the above functions to check if a transfer should happen
 *
 *  - _setAllowlist  - Internal function to add wallets to the allowlist mapping
 *
 */
pragma solidity ^0.8.20;

import {IFID20} from "src/interface/IFID20.sol";
import {IFID20Metadata} from "src/interface/IFID20Metadata.sol";
import {Context} from "lib/openzeppelin-contracts/contracts/utils/Context.sol";
import {IFID20Errors} from "src/interface/IFID20Errors.sol";
import {IFIDStorage} from "src/interface/IFIDStorage.sol";

abstract contract FID20 is Context, IFID20, IFID20Metadata, IFID20Errors {
    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /// FID Custom Variables
    IFIDStorage private _fidStorage;
    mapping(address => bool) private _allowlist;

    error FID20InvalidTransfer(string message, address attemptedAddress);

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_, address fidContract_) {
        _name = name_;
        _symbol = symbol_;
        _fidStorage = IFIDStorage(fidContract_);

        // 0x0 address needs to be on allowlist for mints and burns
        _setAllowlist(address(0), true);
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
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
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
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
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
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     *
     * --- FID20 Custom logic added ---
     *  Hook into _FID20Checks added
     * --- FID20 Custom logic added ---
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        // hook for FID20 custom logic
        _allowTransfer(from, to);

        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
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
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     * ```
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }

    /**
     * @dev FID20 custom logic
     *
     *  Call the external FIDStorage contract to see if wallet has
     *  been linked to a Farcaster account.
     *  If an account is found, a value other than zero is returned.
     *  This is called in a try catch block as it's an external contract.
     *
     */
    function isFIDWallet(address wallet) public view returns (bool) {
        try _fidStorage.ownerFid(wallet) returns (uint256 fid) {
            if (fid != 0) {
                return true;
            } else {
                return false;
            }
        } catch {
            return false;
        }
    }

    /**
     * @dev FID20 custom logic
     *
     *  Checks if a wallet has been added to the allowlist.
     *
     */
    function isAllowlisted(address wallet) public view returns (bool) {
        return _allowlist[wallet];
    }

    /**
     * @dev FID20 custom logic
     *
     *  Internal function to set wallets on the Allowlist
     *
     */
    function _setAllowlist(address _address, bool _allowed) internal {
        _allowlist[_address] = _allowed;
    }

    /**
     * @dev FID20 custom logic
     *
     *    Hook called in _update (standard erc20 function)
     *  ---------------------------
     *  Tokens can only be transferred to and from either a wallet that
     *  has a Farcaster account or wallets that have been added to
     *  the allowlist mapping.
     *
     *
     */
    function _allowTransfer(address to, address from) internal view {
        bool isFromOnAllowlist = isAllowlisted(from);
        bool isFromFID = isFIDWallet(from);

        bool isToOnAllowlist = isAllowlisted(to);
        bool isToFID = isFIDWallet(to);

        // check from
        if (!isFromOnAllowlist && !isFromFID) {
            revert FID20InvalidTransfer("Transfers can only be made from Farcaster or allowlist addresses", from);
        }

        // check to
        if (!isToOnAllowlist && !isToFID) {
            revert FID20InvalidTransfer("Transfers can only be made to Farcaster or allowlist addresses", from);
        }
    }
}