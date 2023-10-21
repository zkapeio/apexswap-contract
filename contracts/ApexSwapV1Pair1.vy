# @version >=0.3
"""
@title ApexSwap AMM DEX V1 Pair
@author zkape.io
"""

interface IERC165:
    def setApprovalForAll(_operator: address, _approved: bool): nonpayable

interface IERC721:
    def balanceOf(_owner: address) -> uint256: view
    def ownerOf(_tokenId: uint256) -> address: view

interface IERC1155:
    def balanceOf(_owner: address, _id: uint256) -> uint256: view
    def balanceOfBatch(_owners: DynArray[address, 255], _ids: DynArray[uint256, 255]) -> DynArray[uint256, 255]: view

interface IERC20:
    def balanceOf(_owner: address) -> uint256: view
    def approve(_operator: address, _value: uint256): nonpayable

interface ApexSwapV1Factory:
    def get_pair_dynamic_info(_pair: address) -> uint256[4]: view

event Setup:
    _state: bool
    _router: address
    _factory: address
    _ticket: indexed(address)
    _nft_contract: indexed(address)
    _erc20_contract: indexed(address)
    _ticket_id: uint256
    _is_trade: bool
    _is_nonfungible: bool

event Swap:
    _sender: indexed(address)
    _target: indexed(address)
    _value: uint256
    _calldata: Bytes[100000]

event SetPrice:
    _controller: indexed(address)
    _old_price: uint256
    _new_price: uint256

event SetDeltaCurve:
    _controller: indexed(address)
    _old_delta: uint256
    _new_delta: uint256

event SetSwapFee:
    _controller: indexed(address)
    _old_fee: uint256
    _new_fee: uint256


# Initialize contract
initialized: bool

MAX_SIZE: constant(uint256) = 50

router: public(address)
factory: public(address)
token0: public(address)
token1: public(address)
delta_type: public(uint256)
delta_curve: public(uint256)
swap_fee: public(uint256)
current_price: public(uint256)

# pair type
# 0: trade type
# 1: ETH type
# 2: ERC721 type
pair_type: public(uint256)

# True -> 721, False -> 1155
is_nonfungible: public(bool)
is_trade: public(bool)

block_timestamp_last: uint256
owner: public(address)
ticket_id: public(uint256)
ticket: public(address)


@external
def __init__():
    self.owner = msg.sender


@payable
@external
def __default__():
    pass


@view
@external
def get_reserves() -> (uint256, uint256, uint256):
    token0_reserve: uint256 = 0
    token1_reserve: uint256 = 0

    if self.is_nonfungible:
        if self.token1 == empty(address):
            token0_reserve = IERC721(self.token0).balanceOf(self)
            token1_reserve = self.balance
        else:
            token0_reserve = IERC20(self.token1).balanceOf(self)
            token1_reserve = self.balance

    return token0_reserve, token1_reserve, self.block_timestamp_last


@view
@external
def get_reserves_1155(_id: uint256) -> (uint256, uint256, uint256):
    token0_reserve: uint256 = 0
    token1_reserve: uint256 = 0

    if not self.is_nonfungible:
        if self.token1 == empty(address):
            token0_reserve = IERC1155(self.token0).balanceOf(self, _id)
            token1_reserve = self.balance
        else:
            token0_reserve = IERC20(self.token1).balanceOf(self)
            token1_reserve = self.balance

    return token0_reserve, token1_reserve, self.block_timestamp_last


@internal
def _update_price(_sender: address, _new_price: uint256):

    old_price: uint256 = self.current_price
    self.current_price = _new_price
    log SetPrice(_sender, old_price, _new_price)


@internal
def _update_delta_curve(_sender: address, _new_delta_curve: uint256):

    old_delta_curve: uint256 = self.delta_curve
    self.delta_curve = _new_delta_curve
    log SetDeltaCurve(_sender, old_delta_curve, _new_delta_curve)


@internal
def _update_swap_fee(_sender: address, _new_swap_fee: uint256):

    old_swap_fee: uint256 = self.swap_fee
    self.swap_fee = _new_swap_fee
    log SetSwapFee(_sender, old_swap_fee, _new_swap_fee)


@payable
@external
def setup(
    _ticket_id: uint256, 
    _pair_type: uint256,
    _router: address, 
    _factory: address, 
    _ticket: address,
    _token0: address, 
    _token1: address,
    _trade: bool,
    _is_nonfungible: bool
) -> bool:

    assert not self.initialized, "APEX:: INVALID CALL"
    self.pair_type = _pair_type
    self.ticket_id = _ticket_id
    self.router = _router
    self.factory = _factory
    self.ticket = _ticket
    self.token0 = _token0
    self.token1 = _token1

    pd: uint256[4] = ApexSwapV1Factory(_factory).get_pair_dynamic_info(self)
    self.delta_type = pd[0]
    self.delta_curve = pd[1]
    self.swap_fee = pd[2]
    self.current_price = pd[3]
    
    self.is_trade = _trade
    self.is_nonfungible = _is_nonfungible
    self.initialized = True

    IERC165(_token0).setApprovalForAll(_router, True)
    
    if _token1 != empty(address):
        IERC20(_token1).approve(_router, MAX_UINT256)
        IERC20(_token1).approve(self, MAX_UINT256)

    log Setup(self.initialized, _router, _factory, _ticket, _token0, _token1, _ticket_id, _trade, _is_nonfungible)

    return True


@external
def update_pool(_new_price: uint256, _new_delta_curve: uint256, _new_swap_fee: uint256):
    assert _new_price != 0, "APEX:: ENTER VALID AMOUNT"    
    assert _new_delta_curve != 0, "APEX:: ENTER VALID AMOUNT"   
    assert _new_swap_fee != 0, "APEX:: ENTER VALID AMOUNT"   

    ow: address = IERC721(self.ticket).ownerOf(self.ticket_id)
    assert msg.sender == ow, "APEX:: FORK OWNER"
    
    self._update_price(msg.sender, _new_price)
    self._update_delta_curve(msg.sender, _new_delta_curve)
    self._update_swap_fee(msg.sender, _new_swap_fee)


@payable
@external
def swap(_target: address, _calldata: Bytes[100000], _value: uint256, _current_price: uint256) -> bool:
    ow: address = IERC721(self.ticket).ownerOf(self.ticket_id)
    assert msg.sender == self.router or msg.sender == ow, "APEX:: CAN ONLY BE CALLED BY ROUTER" 

    success: bool = False
    response: Bytes[32] = b""
    success, response = raw_call(_target, _calldata, max_outsize=32, value=_value, revert_on_failure=False)
    
    assert success, "OS: call failed"

    self.current_price = _current_price
    self.block_timestamp_last = block.timestamp
    log Swap(msg.sender, _target, _value, _calldata)

    return success
