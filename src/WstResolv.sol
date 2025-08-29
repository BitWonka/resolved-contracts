// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*
 * ██╗    ██╗███████╗████████╗    ██████╗ ███████╗███████╗ ██████╗ ██╗    ██╗   ██╗
 * ██║    ██║██╔════╝╚══██╔══╝    ██╔══██╗██╔════╝██╔════╝██╔═══██╗██║    ██║   ██║
 * ██║ █╗ ██║███████╗   ██║       ██████╔╝█████╗  ███████╗██║   ██║██║    ██║   ██║
 * ██║███╗██║╚════██║   ██║       ██╔══██╗██╔══╝  ╚════██║██║   ██║██║    ╚██╗ ██╔╝
 * ╚███╔███╔╝███████║   ██║       ██║  ██║███████╗███████║╚██████╔╝███████╗╚████╔╝
 *  ╚══╝╚══╝ ╚══════╝   ╚═╝       ╚═╝  ╚═╝╚══════╝╚══════╝ ╚═════╝ ╚══════╝ ╚═══╝
 *
 *  - Resolved.finance
 *
 */

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IStResolv {
    function claim(address _user, address _receiver) external;

    function deposit(uint256 _amount, address _receiver) external;
}

contract WstResolv is ERC4626, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice stRESOLV (also the staking contract).
    IStResolv public immutable stResolv;

    /// @notice RESOLV reward token received when claiming.
    IERC20 public immutable resolv;

    uint256 public lastHarvest;

    event Harvest(uint256 gained);

    constructor(
        address _stResolv, // underlying
        address _resolv, // reward token
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC20(_name, _symbol) ERC4626(IERC20(_stResolv)) Ownable(_owner) {
        stResolv = IStResolv(_stResolv);
        resolv = IERC20(_resolv);
        // we deposit resolv for stresolv immediately, so we safely set max approve
        SafeERC20.forceApprove(resolv, _stResolv, type(uint256).max);
    }

    /*//////// OWNER FUNCTIONS  ////////*/

    /// @notice Pause user entries (deposit/mint/harvest).
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause user entries (deposit/mint/harvest).
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Rescue non-core tokens inadvertently sent to this contract.
     * @dev    Cannot rescue the underlying (stRESOLV) or the vault’s own share token.
     * @param token  ERC20 token address to rescue.
     * @param to     Recipient address.
     * @param amount Amount to transfer.
     */
    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(token != address(asset()), "cannot rescue asset");
        require(token != address(this), "cannot rescue shares");
        IERC20(token).safeTransfer(to, amount);
    }

    /*//////// HARVEST LOGIC ////////*/

    /**
     * @notice Claim RESOLV rewards and stake them back into stRESOLV.
     * @dev    Permissionless, callers should consider gas economics.
     *         Paused modifier
     * @return gained Amount of stRESOLV added to the vault’s balance by this harvest.
     */
    function harvest() external whenNotPaused nonReentrant returns (uint256 gained) {
        return _executeHarvest();
    }

    /**
     * @dev Internal implementation:
     *      - Claims RESOLV to this contract.
     *      - Stakes full RESOLV balance back into stRESOLV, minting stRESOLV to this contract.
     *      - Emits `Harvest(gained)` with the net stRESOLV increase.
     *
     * @return gained Amount of stRESOLV added to the vault’s balance by this harvest.
     */
    function _executeHarvest() internal returns (uint256 gained) {
        address vault = address(this);
        uint256 beforeBal = IERC20(asset()).balanceOf(vault);

        // 1) claim resolv
        stResolv.claim(vault, vault);

        // 2) stake all RESOLV into stRESOLV
        uint256 resolvBalance = resolv.balanceOf(vault);
        if (resolvBalance != 0) {
            stResolv.deposit(resolvBalance, vault); // mints stRESOLV to this vault
        }

        uint256 afterBal = IERC20(asset()).balanceOf(vault);
        gained = afterBal - beforeBal;
        lastHarvest = block.timestamp;
        if (gained != 0) emit Harvest(gained);
    }

    /*//////// OVERRIDES /////////

    /**
    * @inheritdoc ERC4626
     * @dev Paused modifier prevents new deposits when paused
     *      Reentrancy guard
     */
    function deposit(uint256 assets, address receiver)
        public
        override
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        shares = super.deposit(assets, receiver);
    }

    /**
     * @inheritdoc ERC4626
     * @dev Paused modifier prevents new mints when paused
     *      Reentrancy guard
     */
    function mint(uint256 shares, address receiver)
        public
        override
        whenNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        assets = super.mint(shares, receiver);
    }
}
