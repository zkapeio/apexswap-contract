# @version >=0.3
"""
@title ApexSwap AMM DEX V1 Library
@author zkape.io
"""

MAX_SIZE: constant(uint256) = 50

interface IERC721Metadata:
    def name() -> String[100]: view
    def symbol()-> String[100]: view
    def tokenURI(tokenId: uint256) -> String[300]: view
    def balanceOf(owner: address) -> uint256: view
    def ownerOf(tokenId: uint256) -> address: view
    def getApproved(tokenId: uint256) -> address: view
    def isApprovedForAll(owner: address, operator: address) -> bool: view
    def baseURI() -> String[300]: view
    def owner() -> address: view

interface IERC721Enumerable:
    def totalSupply() -> uint256: view
    def tokenOfOwnerByIndex(owner: address, index: uint256) -> uint256: view
    def tokenByIndex(index: uint256) -> uint256: view
    def supportsInterface(interfaceId: bytes4) -> bool: view

interface ApexSwapV1Pair:
    def token0() -> address: view
    def token1() -> address: view
    def controller() -> address: view
    def current_price() -> uint256: view
    def swap_fee() -> uint256: view
    def delta_type() -> uint256: view
    def delta_curve() -> uint256: view
    def pair_type() -> uint256: view
    def is_trade() -> bool: view
    def get_reserves() -> (uint256, uint256, uint256): view

interface ApexSwapV1Router:
    def get_ape_fee(_amountIn: uint256) -> uint256: view
    def ape_fund() -> address: view
    def ape_fee() -> uint256: view

event UpdateRouter:
    _old_router: indexed(address)
    _new_router: indexed(address)

owner: public(address)
router: public(address)

@external
def __init__():
    self.owner = msg.sender


@pure
@internal
def _linear_delta_buy_info(
    _pair: address,
    _number_items: uint256,
    _current_price: uint256,
    _delta_curve: uint256,
    _swap_fee: uint256,
    _protocol_fee: uint256
) -> (uint256, uint256, uint256):
    assert _number_items != 0, "APEX:: UNVALID ITEMS"

    # 购买完所有的NFT后的价格
    new_current_price: uint256 = _current_price + _number_items * _delta_curve
    assert new_current_price <= MAX_UINT256, "APEX:: UNVALID PRICE"

    # 购买所有的NFT需要花费多少ETH
    input_value: uint256 = _number_items * _current_price + (_number_items * (_number_items - 1) * _delta_curve) / 2
    # 避免机器人套利 向上加一个单位
    input_value += _delta_curve

    if ApexSwapV1Pair(_pair).is_trade():
        add_swap_fee: uint256 = input_value * _swap_fee / 1000
        input_value += add_swap_fee

    protocol_fee: uint256 = input_value * _protocol_fee / 1000
    input_value += protocol_fee

    return new_current_price, input_value, protocol_fee


@pure
@internal
def _linear_delta_sell_info(
    _pair: address,
    _number_items: uint256,
    _current_price: uint256,
    _delta_curve: uint256,
    _swap_fee: uint256,
    _protocol_fee: uint256
) -> (uint256, uint256, uint256):

    assert _number_items != 0, "APEX:: UNVALID ITEMS"

    price_change: uint256 = _number_items * _delta_curve
    new_current_price: uint256 = 0
    new_num_items: uint256 = _number_items

    if price_change > _current_price:
        new_current_price = 0
        # 当价格为0时需要卖出多少个NFT
        new_num_items = _current_price / _delta_curve + 1
    else:
        new_current_price = _current_price - price_change
    
    output_value: uint256 = new_num_items * _current_price - (new_num_items * (new_num_items - 1) * _delta_curve) / 2

    # 避免机器人套利 向下减一个单位
    output_value -= _delta_curve

    if ApexSwapV1Pair(_pair).is_trade():
        # 仅适用于双向流动池
        add_swap_fee: uint256 = output_value * _swap_fee / 1000
        output_value -= add_swap_fee

    protocol_fee: uint256 = output_value * _protocol_fee / 1000
    output_value -= protocol_fee

    return new_current_price, output_value, protocol_fee
  

@pure
@internal
def _exponential_delta_buy_info(
    _pair: address,
    _number_items: uint256,
    _current_price: uint256,
    _delta_curve: uint256,
    _swap_fee: uint256,
    _protocol_fee: uint256
) -> (uint256, uint256, uint256):

    assert _number_items != 0 and _number_items <= MAX_SIZE, "APEX:: UNVALID ITEMS"

    # 购买所有的NFT需要花费多少ETH
    # 最多计算购买50个总金额
    new_current_price: uint256 = _current_price
    input_value: uint256 = 0
    t: uint256 = 0

    for i in range(MAX_SIZE):
        if i >= _number_items:
            break
        else:
            t = new_current_price * (_delta_curve + 10 ** 18) / 10 ** 18
            new_current_price = t
            input_value += t
    
    assert new_current_price <= MAX_UINT256, "APEX:: UNVALID PRICE"

    # 避免机器人套利 往上加一个点位
    input_value += ((new_current_price * _delta_curve) / 10 ** 18)

    if ApexSwapV1Pair(_pair).is_trade():
        add_swap_fee: uint256 = input_value * _swap_fee / 1000
        input_value += add_swap_fee

    protocol_fee: uint256 = input_value * _protocol_fee / 1000
    input_value += protocol_fee

    return new_current_price, input_value, protocol_fee


@pure
@internal
def _exponential_delta_sell_info(
    _pair: address,
    _number_items: uint256,
    _current_price: uint256,
    _delta_curve: uint256,
    _swap_fee: uint256,
    _protocol_fee: uint256
) -> (uint256, uint256, uint256):

    assert _number_items != 0, "APEX:: UNVALID ITEMS"

    new_current_price: uint256 = _current_price
    output_value: uint256 = 0
    t: uint256 = 0

    for i in range(MAX_SIZE):
        if i >= _number_items:
            break
        else:
            t = new_current_price * (10 ** 18 - _delta_curve) / 10 ** 18
            new_current_price = t
            output_value += t
    
    assert new_current_price > 0, "APEX:: UNVALID PRICE"

    # 避免机器人套利 往下减一个点位
    output_value -= ((new_current_price * _delta_curve) / 10 ** 18)

    if ApexSwapV1Pair(_pair).is_trade():
        add_swap_fee: uint256 = output_value * _swap_fee / 1000
        output_value -= add_swap_fee

    protocol_fee: uint256 = output_value * _protocol_fee / 1000
    output_value -= protocol_fee

    return new_current_price, output_value, protocol_fee


@pure
@internal
def _xyk_dalta_buy_info(
    _nft_balance: uint256,
    _token_balance: uint256,
    _number_items: uint256,
    _swap_fee: uint256,
    _protocol_fee: uint256
) -> (uint256, uint256, uint256):

    assert _number_items != 0 and _nft_balance >= _number_items, "APEX:: UNVALID ITEMS"
    
    input_value_without_fee: uint256 = (_number_items * _token_balance) / (_nft_balance - _number_items)
    
    swap_fee: uint256 = input_value_without_fee * _swap_fee / 1000
    protocol_fee: uint256 = input_value_without_fee * _protocol_fee / 1000

    input_value: uint256 = input_value_without_fee + swap_fee + protocol_fee
    new_current_price: uint256 = (_token_balance + input_value_without_fee + swap_fee) / (_nft_balance - _number_items)

    return new_current_price, input_value, protocol_fee


@pure
@internal
def _xyk_dalta_sell_info(
    _nft_balance: uint256,
    _token_balance: uint256,
    _number_items: uint256,
    _swap_fee: uint256,
    _ape_fee: uint256
) -> (uint256, uint256, uint256):

    assert _number_items != 0, "APEX:: UNVALID ITEMS"
    
    output_value_without_fee: uint256 = (_number_items * _token_balance) / (_nft_balance + _number_items)

    swap_fee: uint256 = output_value_without_fee * _swap_fee / 1000
    protocol_fee: uint256 = output_value_without_fee * _ape_fee / 1000
    output_value: uint256 = output_value_without_fee - swap_fee - protocol_fee
    new_current_price: uint256 = (_token_balance + output_value_without_fee + swap_fee) / (_nft_balance - _number_items)

    return new_current_price, output_value, protocol_fee



@view
@internal
def _pair_buy_basic_info(_pair: address, _number_items: uint256) -> (uint256, uint256, uint256):
    current_price: uint256 = ApexSwapV1Pair(_pair).current_price()
    delta_type: uint256 = ApexSwapV1Pair(_pair).delta_type()
    delta_curve: uint256 = ApexSwapV1Pair(_pair).delta_curve()
    swap_fee: uint256 = ApexSwapV1Pair(_pair).swap_fee()

    new_current_price: uint256 = 0
    input_value: uint256 = 0
    protocol_fee: uint256 = 0
    token_balance: uint256 = 0
    nft_balance: uint256 = 0
    t: uint256 = 0

    ape_fee: uint256 = ApexSwapV1Router(self.router).ape_fee()

    assert delta_type in [0, 1, 2], "APEX:: UNVALID TYPE"

    if delta_type == 0:
        new_current_price, input_value, protocol_fee = self._linear_delta_buy_info(_pair, _number_items, current_price, delta_curve, swap_fee, ape_fee)
    elif delta_type == 1:
        new_current_price, input_value, protocol_fee = self._exponential_delta_buy_info(_pair, _number_items, current_price, delta_curve, swap_fee, ape_fee)
    elif delta_type == 2:
        nft_balance, token_balance, t = ApexSwapV1Pair(_pair).get_reserves()
        new_current_price, input_value, protocol_fee = self._xyk_dalta_buy_info(nft_balance, token_balance, _number_items, swap_fee, ape_fee)

    return new_current_price, input_value, protocol_fee


@view
@internal
def _pair_sell_basic_info(_pair: address, _number_items: uint256) -> (uint256, uint256, uint256):
    current_price: uint256 = ApexSwapV1Pair(_pair).current_price()
    delta_type: uint256 = ApexSwapV1Pair(_pair).delta_type()
    delta_curve: uint256 = ApexSwapV1Pair(_pair).delta_curve()
    swap_fee: uint256 = ApexSwapV1Pair(_pair).swap_fee()

    new_current_price: uint256 = 0
    output_value: uint256 = 0
    protocol_fee: uint256 = 0
    token_balance: uint256 = 0
    nft_balance: uint256 = 0
    t: uint256 = 0
    ape_fee: uint256 = ApexSwapV1Router(self.router).ape_fee()

    assert delta_type in [0, 1, 2], "APEX:: UNVALID TYPE"

    if delta_type == 0:
        new_current_price, output_value, protocol_fee = self._linear_delta_sell_info(_pair, _number_items, current_price, delta_curve, swap_fee, ape_fee)
    elif delta_type == 1:
        new_current_price, output_value, protocol_fee = self._exponential_delta_sell_info(_pair, _number_items, current_price, delta_curve, swap_fee, ape_fee)
    elif delta_type == 2:
        nft_balance, token_balance, t = ApexSwapV1Pair(_pair).get_reserves()
        new_current_price, output_value, protocol_fee = self._xyk_dalta_sell_info(nft_balance, token_balance, _number_items, swap_fee, ape_fee)

    return new_current_price, output_value, protocol_fee


@view
@external
def pair_buy_basic_info(_pair: address, _number_items: uint256) -> (uint256, uint256, uint256):
    return self._pair_buy_basic_info(_pair, _number_items)


@view
@external
def pair_sell_basic_info(_pair: address, _number_items: uint256) -> (uint256, uint256, uint256):
    return self._pair_sell_basic_info(_pair, _number_items)


@view
@external
def get_input_value(
    _delta_type: uint256, 
    _pair: address, 
    _number_items: uint256, 
    _current_price: uint256, 
    _delta_curve: uint256, 
    _swap_fee: uint256
) -> (uint256, uint256, uint256):

    new_current_price: uint256 = 0
    input_value: uint256 = 0
    protocol_fee: uint256 = 0
    nft_balance: uint256 = 0
    token_balance: uint256 = 0
    t: uint256 = 0
    ape_fee: uint256 = ApexSwapV1Router(self.router).ape_fee()

    if _delta_type == 0:
        new_current_price, input_value, protocol_fee = self._linear_delta_buy_info(_pair, _number_items, _current_price, _delta_curve, _swap_fee, ape_fee)
    elif _delta_type == 1:
        new_current_price, input_value, protocol_fee = self._exponential_delta_buy_info(_pair, _number_items, _current_price, _delta_curve, _swap_fee, ape_fee)
    elif _delta_type == 2:
        nft_balance, token_balance, t = ApexSwapV1Pair(_pair).get_reserves()
        new_current_price, input_value, protocol_fee = self._xyk_dalta_buy_info(nft_balance, token_balance, _number_items, _swap_fee, ape_fee)

    return new_current_price, input_value, protocol_fee


@view
@external
def get_output_value(
    _delta_type: uint256, 
    _pair: address, 
    _number_items: uint256, 
    _current_price: uint256, 
    _delta_curve: uint256, 
    _swap_fee: uint256
) -> (uint256, uint256, uint256):

    new_current_price: uint256 = 0
    output_value: uint256 = 0
    protocol_fee: uint256 = 0
    nft_balance: uint256 = 0
    token_balance: uint256 = 0
    t: uint256 = 0
    ape_fee: uint256 = ApexSwapV1Router(self.router).ape_fee()

    if _delta_type == 0:
        new_current_price, output_value, protocol_fee = self._linear_delta_sell_info(_pair, _number_items, _current_price, _delta_curve, _swap_fee, ape_fee)
    elif _delta_type == 1:
        new_current_price, output_value, protocol_fee = self._exponential_delta_sell_info(_pair, _number_items, _current_price, _delta_curve, _swap_fee, ape_fee)
    elif _delta_type == 2:
        nft_balance, token_balance, t = ApexSwapV1Pair(_pair).get_reserves()
        new_current_price, output_value, protocol_fee = self._xyk_dalta_sell_info(nft_balance, token_balance, _number_items, _swap_fee, ape_fee)

    return new_current_price, output_value, protocol_fee


@external
def set_router(_new_router: address):
    assert msg.sender == self.owner, "APEX:: ONLY OWNER"

    _old_router: address = self.router
    self.router = _new_router
    log UpdateRouter(_old_router, _new_router)


