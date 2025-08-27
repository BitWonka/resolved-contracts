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

	IStResolv public immutable stResolv; // stRESOLV proxy (also staking contract)
	IERC20 public immutable resolv; // reward token received on claim()

	bool public harvestOnDeposit = false;
	uint256 public minHarvestInterval = 1 hours;
	uint256 public lastHarvest;

	event Harvest(uint256 gained);
	event HarvestConfigSet(bool onDeposit, uint256 minInterval);

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

	/* Owner functions */
	function pause() external onlyOwner {
		_pause();
	}

	function unpause() external onlyOwner {
		_unpause();
	}

	function setHarvestConfig(bool onDeposit, uint256 minInterval) external onlyOwner {
		harvestOnDeposit = onDeposit;
		minHarvestInterval = minInterval;
		emit HarvestConfigSet(onDeposit, minInterval);
	}

	function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
		require(token != address(asset()), "cannot rescue asset");
		require(token != address(this), "cannot rescue shares");
		IERC20(token).safeTransfer(to, amount);
	}

	/* harvest logic */

	function harvest() external nonReentrant returns (uint256 gained) {
		return _executeHarvest();
	}

	function _harvest() internal {
		if (!harvestOnDeposit) return;
		_executeHarvest();
	}

	function _executeHarvest() internal returns (uint256 gained) {
		if (block.timestamp < lastHarvest + minHarvestInterval) return 0;

		address vault = address(this);
		uint256 beforeBal = IERC20(asset()).balanceOf(address(this));

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

	/* overrides */

	function deposit(uint256 assets, address receiver)
	public
	override
	whenNotPaused
	nonReentrant
	returns (uint256 shares)
	{
		_harvest();
		shares = super.deposit(assets, receiver);
	}

	function mint(uint256 shares, address receiver)
	public
	override
	whenNotPaused
	nonReentrant
	returns (uint256 assets)
	{
		_harvest();
		assets = super.mint(shares, receiver);
	}

	function withdraw(uint256 assets, address receiver, address owner_)
	public
	override
	whenNotPaused
	nonReentrant
	returns (uint256 shares)
	{
		// No harvest here.
		shares = super.withdraw(assets, receiver, owner_);
	}

	function redeem(uint256 shares, address receiver, address owner_)
	public
	override
	whenNotPaused
	nonReentrant
	returns (uint256 assets)
	{
		// No harvest here.
		assets = super.redeem(shares, receiver, owner_);
	}
}
