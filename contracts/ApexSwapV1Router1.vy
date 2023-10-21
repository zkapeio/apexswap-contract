# @version >=0.3
"""
@title ApexSwap AMM DEX V1 Router
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

interface IERC20Metadata:
    def name() -> String[100]: view
    def symbol()-> String[100]: view 
    def balanceOf(owner: address) -> uint256: view
    def approve(_operator: address, _value: uint256): nonpayable

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
    def ticket() -> address: view
    def ticket_id() -> uint256: view

interface ApexSwapV1Libray:
    def pair_buy_basic_info(_pair: address, _number_items: uint256) -> (uint256, uint256, uint256): view
    def pair_sell_basic_info(_pair: address, _number_items: uint256) -> (uint256, uint256, uint256): view
    def get_input_value(
        _delta_type: uint256,
        _pair: address,
        _number_items: uint256,
        _current_price: uint256,
        _delta_curve: uint256,
        _swap_fee: uint256) -> (uint256, uint256, uint256): view
    def get_output_value(
        _delta_type: uint256,
        _pair: address,
        _number_items: uint256,
        _current_price: uint256,
        _delta_curve: uint256,
        _swap_fee: uint256) -> (uint256, uint256, uint256): view

event SwapETHForNFT:
    _pair: indexed(address)
    _token0: indexed(address)
    _recipient: indexed(address)
    _buy_amount: uint256
    _token_ids: DynArray[uint256, MAX_SIZE]
    
event SwapNFTForETH:
    _pair: indexed(address)
    _token0: indexed(address)
    _recipient: indexed(address)
    _token_ids: DynArray[uint256, MAX_SIZE]

event SwapERC20TokenForERC721:
    _pair: indexed(address)
    _sender: address
    _number_items: uint256
    _token_ids: DynArray[uint256, MAX_SIZE]

event SwapERC721ForERC20Token:
    _pair: indexed(address)
    _sender: address
    _number_items: uint256
    _token_ids: DynArray[uint256, MAX_SIZE]

event AggregatorSwapETHForNFT:
    _pair: indexed(address)
    _token0: indexed(address)
    _recipient: indexed(address)
    _buy_amount: uint256
    _token_ids: DynArray[uint256, MAX_SIZE]

event AddLiquidity:
    _pair: indexed(address)
    _token0: indexed(address)
    _sender: indexed(address)
    _amount_in: uint256
    _token_id: uint256

event AddLiquidityEN:
    _pair: indexed(address)
    _token0: indexed(address)
    _token1: address
    _sender: indexed(address)
    _amount_in: uint256
    _token_id: uint256

event AddLiquidityETH:
    _pair: indexed(address)
    _nft_address: indexed(address)
    _sender: indexed(address)
    _amount_in: uint256

event AddLiquidityERC20:
    _pair: indexed(address)
    _token_address: indexed(address)
    _sender: indexed(address)
    _amount_in: uint256

event AddLiquidityERC721NFT:
    _pair: indexed(address)
    _token0: indexed(address)
    _sender: indexed(address)
    _token_id: uint256

event RemoveLiquidity:
    _pair: indexed(address)
    _token0: indexed(address)
    _sender: indexed(address)
    _amount_in: uint256
    _token_id: uint256

event RemoveLiquidityEN:
    _pair: indexed(address)
    _token0: indexed(address)
    _token1: address
    _sender: indexed(address)
    _amount_in: uint256
    _token_id: uint256

event RemoveLiquidityETH:
    _pair: indexed(address)
    _sender: indexed(address)
    _amount_in: uint256

event RemoveLiquidityERC20:
    _pair: indexed(address)
    _sender: indexed(address)
    _amount_in: uint256

event RemoveLiquidityERC721NFT:
    _pair: indexed(address)
    _token0: indexed(address)
    _sender: indexed(address)
    _token_id: uint256

event UpdateNewFactory:
    _sender: indexed(address)
    _old_factory: indexed(address)
    _new_factory: indexed(address)  

event UpdateNewLibrary:
    _sender: indexed(address)
    _old_library: indexed(address)
    _new_library: indexed(address)  

event UpdateNewFund:
    _sender: indexed(address)
    _old_fund: indexed(address)
    _new_fund: indexed(address) 

event UpdateNewFee:
    _sender: indexed(address)
    _old_fee: uint256
    _new_fee: uint256

struct AggregatorSwapPair:
    pair: address
    number_item: uint256
    token_ids: DynArray[uint256, MAX_SIZE]


is_approved: HashMap[address, HashMap[address, bool]]
pair_for_items: HashMap[address, uint256]

ape_fee: public(uint256)
ape_fund: public(address)
factory: public(address)
owner: public(address)
library: public(address)


@external
def __init__(_fee: uint256, _fund: address, _library: address):
    self.owner = msg.sender
    self.ape_fee = _fee
    self.ape_fund = _fund
    self.library = _library


@internal
def _check_deadline(_deadline: uint256):
    assert block.timestamp <= _deadline, "APEX:: DEADLINE PASSED"


@internal
def _get_buy_info(
    _pair: address,
    _number_items: uint256
) -> (uint256, uint256, uint256):

    assert _number_items != 0, "APEX:: UNVALID ITEMS"

    new_current_price: uint256 = 0
    input_value: uint256 = 0
    protocol_fee: uint256 = 0
    new_current_price, input_value, protocol_fee = ApexSwapV1Libray(self.library).pair_buy_basic_info(_pair, _number_items)

    return new_current_price, input_value, protocol_fee


@internal
def _get_sell_info(
    _pair: address,
    _number_items: uint256
) -> (uint256, uint256, uint256):

    assert _number_items != 0, "APEX:: UNVALID ITEMS"

    new_current_price: uint256 = 0
    output_value: uint256 = 0
    protocol_fee: uint256 = 0
    new_current_price, output_value, protocol_fee = ApexSwapV1Libray(self.library).pair_sell_basic_info(_pair, _number_items)

    return new_current_price, output_value, protocol_fee


@internal
def _check_ticket_owner(_pair: address, _owner: address):
    
    t_id: uint256 = ApexSwapV1Pair(_pair).ticket_id()
    t: address = ApexSwapV1Pair(_pair).ticket()
    ow: address = IERC721Metadata(t).ownerOf(t_id)

    assert _owner == ow, "APEX:: ONLY OWNER"


@internal
def _check_balance(_token_address: address, _recipient: address, _amount_in: uint256):
    
    amount_out: uint256 = IERC20Metadata(_token_address).balanceOf(_recipient)
    assert amount_out >= _amount_in, "APEX:: INSUFFICIENT BALANCE"


@internal
def _check_buy_value(_pair: address, _number_items: uint256, _value: uint256):
    new_current_price: uint256 = 0
    input_value: uint256 = 0
    protocol_fee: uint256 = 0

    new_current_price, input_value, protocol_fee = self._get_buy_info(_pair, _number_items)
    assert _value >= (input_value - protocol_fee), "APEX:: UNVALID PAY"


@internal
def _check_sell_value(_pair: address, _number_items: uint256, _value: uint256):
    new_current_price: uint256 = 0
    output_value: uint256 = 0
    protocol_fee: uint256 = 0

    new_current_price, output_value, protocol_fee = self._get_sell_info(_pair, _number_items)
    assert _value <= (output_value + protocol_fee), "APEX:: UNVALID PAY"


@internal
def _safe_transfer_erc721(_pair: address, _from: address, _to: address, _token_id: uint256) -> bool:

    nft_contract: address = ApexSwapV1Pair(_pair).token0()

    raw_call(
        nft_contract,
        _abi_encode(_from, _to, _token_id, method_id=method_id("transferFrom(address,address,uint256)"))
    )

    return True


@internal
def _safe_transfer_erc20(_token_address: address, _from: address, _to: address, _amount_in: uint256) -> bool:
    
    if not self.is_approved[self][_token_address]:
        response: Bytes[32] = raw_call(
            _token_address,
            _abi_encode(self, MAX_UINT256, method_id=method_id("approve(address,uint256)")),
            max_outsize=32
        )
        if len(response) != 0:
            assert convert(response, bool)
        self.is_approved[self][_token_address] = True

    raw_call(
        _token_address,
        _abi_encode(_from, _to, _amount_in, method_id=method_id("transferFrom(address,address,uint256)"))
    )

    return True


@internal
def _call_eth(_target: address, _recipient: address, _value: uint256, _current_price: uint256):
    
    raw_call(
        _target,
        _abi_encode(
            _recipient,
            b"",
            _value,
            _current_price,
            method_id=method_id("swap(address,bytes,uint256,uint256)")
        )
    )


@internal
def _call_erc721(_target: address, _nft_address: address, _recipient: address, _token_id: uint256, _value: uint256, _current_price: uint256):

    raw_call(
        _target, 
        _abi_encode(
            _nft_address, 
            _abi_encode(_target, _recipient, _token_id, method_id=method_id("transferFrom(address,address,uint256)")),
            _value,
            _current_price,
            method_id=method_id("swap(address,bytes,uint256,uint256)")
        )
    )


@internal
def _call_erc20(_target: address, _token_address: address, _recipient: address, _amount_in: uint256, _value: uint256, _current_price: uint256):
    
    raw_call(
        _target,
        _abi_encode(
            _token_address,
            _abi_encode(_target, _recipient, _amount_in, method_id=method_id("transferFrom(address,address,uint256)")),
            _value,
            _current_price,
            method_id=method_id("swap(address,bytes,uint256,uint256)")
        )
    )


@internal
def _swap_erc721_for_eth(
    _pair: address,
    _recipient: address, 
    _number_items: uint256, 
    _token_ids: DynArray[uint256, MAX_SIZE]
) -> (uint256, uint256, uint256):

    assert _number_items == len(_token_ids), "APEX:: UNVALID ITEMS"

    new_current_price: uint256 = 0
    output_value: uint256 = 0
    protocol_fee: uint256 = 0
    new_current_price, output_value, protocol_fee = ApexSwapV1Libray(self.library).pair_sell_basic_info(_pair, _number_items)

    for ids in _token_ids:
        transfer_successful: bool = self._safe_transfer_erc721(
            _pair,
            _recipient,
            _pair,
            ids
        )
        assert transfer_successful, "APEX:: UNVALID TRANSFER"

    return new_current_price, output_value, protocol_fee


@internal
def _swap_erc20_for_erc721(
    _pair: address,
    _nft_address: address,
    _token_address: address,
    _recipient: address,
    _amount_in: uint256,
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE]
) -> (bool, uint256):

    
    new_current_price: uint256 = 0
    input_value: uint256 = 0
    protocol_fee: uint256 = 0
    new_current_price, input_value, protocol_fee = ApexSwapV1Libray(self.library).pair_buy_basic_info(_pair, _number_items)

    transfer_erc20_successful: bool = self._safe_transfer_erc20(_token_address, _recipient, _pair, input_value)
    assert transfer_erc20_successful, "APEX:: UNVALID TRANSFER FOR SEND"

    transfer_erc20_for_ape_fund_successful: bool = self._safe_transfer_erc20(_token_address, _recipient, self.ape_fund, protocol_fee)
    assert transfer_erc20_for_ape_fund_successful, "APEX:: UNVALID TRANSFER FOR APE"

    for i in range(MAX_SIZE):
        if i >= len(_token_ids):
            break
        else:
            self._call_erc721(_pair, _nft_address, _recipient, _token_ids[i], 0, new_current_price)

    return True, input_value
    

@internal
def _swap_erc721_for_erc20(
    _pair: address,
    _nft_address: address,
    _token_address: address,
    _recipient: address,
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE]
) -> bool:

    new_current_price: uint256 = 0
    output_value: uint256 = 0
    protocol_fee: uint256 = 0
    new_current_price, output_value, protocol_fee = ApexSwapV1Libray(self.library).pair_sell_basic_info(_pair, _number_items)

    for i in range(MAX_SIZE):
        if i >= len(_token_ids):
            break
        else:
            transfer_successful: bool = self._safe_transfer_erc721(
                _pair,
                _recipient,
                _pair,
                _token_ids[i]
            )
            assert transfer_successful, "APEX:: UNVALID TRANSFER"

    # tranfer to recipient
    self._call_erc20(_pair, _token_address, _recipient, output_value, 0, new_current_price)

    # tansfer to fund
    self._call_erc20(_pair, _token_address, self.ape_fund, protocol_fee, 0, new_current_price)

    return True


@payable
@external
def aggregator_swap_eth_for_erc721(
    _pairs: DynArray[AggregatorSwapPair, MAX_SIZE],
    _nft_address: address,
    _nft_recipient: address,
    _deadline: uint256
) -> bool:

    assert _nft_address != empty(address) and _nft_recipient != empty(address) and msg.sender != empty(address), "APEX:: UNVALID ADDRESS"

    self._check_deadline(_deadline)

    pay_value: uint256 = 0

    for i in range(MAX_SIZE):
        if i >= len(_pairs):
            break
        else:
            new_current_price: uint256 = 0
            input_value: uint256 = 0
            protocol_fee: uint256 = 0

            new_current_price, input_value, protocol_fee = self._get_buy_info(_pairs[i].pair, _pairs[i].number_item)
            pay_value += input_value
            exact_value: uint256 = input_value - protocol_fee

            # transfer to pool
            raw_call(_pairs[i].pair, b"", value=exact_value)

            # tansfer to fund
            raw_call(self.ape_fund, b"", value=protocol_fee)

            for ids in _pairs[i].token_ids:
                self._call_erc721(_pairs[i].pair, _nft_address, _nft_recipient, ids, 0, new_current_price)

            log AggregatorSwapETHForNFT(_pairs[i].pair, _nft_address, _nft_recipient, input_value, _pairs[i].token_ids)

    if msg.value > pay_value:
        slippage: uint256 = msg.value - pay_value
        assert slippage > 0, "APEX:: UNVALID SLIPPAGE"
        raw_call(_nft_recipient, b"", value=slippage)

    return True


@external
def aggregator_swap_erc721_for_eth(
    _pairs: DynArray[AggregatorSwapPair, MAX_SIZE],
    _nft_address: address,
    _eth_recipient: address,
    _deadline: uint256
) -> bool: 

    assert len(_pairs) != 0, "APEX:: EMPTY PAIR"
    assert _nft_address != empty(address) and _eth_recipient != empty(address) and msg.sender != empty(address), "APEX:: EMPTY ADDRESS"

    self._check_deadline(_deadline)

    for i in range(MAX_SIZE):
        if i >= len(_pairs):
            break
        else:
            new_current_price: uint256 = 0
            output_value: uint256 = 0
            protocol_fee: uint256 = 0

            new_current_price, output_value, protocol_fee = self._swap_erc721_for_eth(
                _pairs[i].pair, 
                _eth_recipient, 
                _pairs[i].number_item, 
                _pairs[i].token_ids
            )

            # transfer to recipient
            self._call_eth(_pairs[i].pair, _eth_recipient, output_value - protocol_fee, new_current_price)

            # transfer to fund
            self._call_eth(_pairs[i].pair, self.ape_fund, protocol_fee, new_current_price)

            log SwapNFTForETH(_pairs[i].pair, _nft_address, _eth_recipient, _pairs[i].token_ids)

    return True


@external
def aggregator_swap_erc20_for_erc721(
    _pairs: DynArray[AggregatorSwapPair, MAX_SIZE],
    _nft_address: address,
    _token_address: address,
    _nft_recipient: address,
    _amount_in: uint256,
    _deadline: uint256
) -> bool:
    
    assert _nft_address != empty(address) and _nft_recipient != empty(address) and msg.sender != empty(address), "APEX:: UNVALID ADDRESS"
    assert _token_address != empty(address), "APEX:: EMPTY ADDRESS"
    assert len(_pairs) != 0, "APEX:: EMPTY PAIRS"

    self._check_deadline(_deadline)
    self._check_balance(_token_address, _nft_recipient, _amount_in)
    self._safe_transfer_erc20(_token_address, _nft_recipient, self, _amount_in)

    pay_value: uint256 = 0

    for i in range(MAX_SIZE):
        if i >= len(_pairs):
            break
        else:
            transfer_sucessful: bool = False
            transfer_sucessful, pay_value = self._swap_erc20_for_erc721(
                _pairs[i].pair, 
                _nft_address, 
                _token_address, 
                _nft_recipient, 
                _amount_in,
                _pairs[i].number_item, 
                _pairs[i].token_ids
            )

            assert transfer_sucessful, "APEX:: UNVALID TRANSFER"

            log SwapERC20TokenForERC721(_pairs[i].pair, _nft_recipient, _pairs[i].number_item, _pairs[i].token_ids)

    if _amount_in > pay_value:
        slippage: uint256 = _amount_in - pay_value
        assert slippage > 0, "APEX:: UNVALID SLIPPAGE"
        self._safe_transfer_erc20(_token_address, self, _nft_recipient, slippage)

    return True


@external
def aggregator_swap_erc721_for_erc20(
    _pairs: DynArray[AggregatorSwapPair, MAX_SIZE],
    _nft_address: address,
    _token_address: address,
    _eth_recipient: address,
    _amount_in: uint256,
    _deadline: uint256
) -> bool:
    
    assert _nft_address != empty(address) and _eth_recipient != empty(address) and msg.sender != empty(address), "APEX:: UNVALID ADDRESS"
    assert _token_address != empty(address), "APEX:: EMPTY ADDRESS"
    assert len(_pairs) != 0, "APEX:: EMPTY PAIRS"

    self._check_deadline(_deadline)
    self._check_balance(_token_address, _eth_recipient, _amount_in)

    for i in range(MAX_SIZE):
        if i >= len(_pairs):
            break
        else:
            new_current_price: uint256 = 0
            output_value: uint256 = 0
            protocol_fee: uint256 = 0

            new_current_price, output_value, protocol_fee = self._swap_erc721_for_eth(
                _pairs[i].pair, 
                _eth_recipient, 
                _pairs[i].number_item, 
                _pairs[i].token_ids
            )

            # transfer to pair
            self._call_erc20(_pairs[i].pair, _token_address, _eth_recipient, output_value, 0, new_current_price)

            # tansfer to fund
            self._call_erc20(_pairs[i].pair, _token_address, self.ape_fund, protocol_fee, 0, new_current_price)

            log SwapERC721ForERC20Token(_pairs[i].pair, _eth_recipient, _pairs[i].number_item, _pairs[i].token_ids)

    return True


@payable
@external
def swap_eth_for_erc721(
    _pair: address,
    _nft_address: address, 
    _nft_recipient: address,
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE],
    _deadline: uint256
) -> bool:
    assert msg.sender != empty(address) and _pair != empty(address) and _nft_recipient != empty(address), "APEX:: UNVALIE ADDRESS"
    assert len(_token_ids) != 0, "APEX:: UNVALID ITEMS"
    assert ApexSwapV1Pair(_pair).pair_type() != 1, "APEX:: PAIR TRADE TYPE"
    self._check_deadline(_deadline)

    input_value: uint256 = 0
    new_current_price: uint256 = 0
    protocol_fee: uint256 = 0
    new_current_price, input_value, protocol_fee = self._get_buy_info(_pair, _number_items)
    assert msg.value >= input_value, "APEX:: UNVALID PAY"

    exact_value: uint256 = input_value - protocol_fee

    for i in range(MAX_SIZE):
        if i >= len(_token_ids):
            break
        else:
            self._call_erc721(_pair, _nft_address, _nft_recipient, _token_ids[i], 0, new_current_price)
    
    # transfer to fund
    raw_call(self.ape_fund, b"", value=protocol_fee)

    # tranfer to pair
    raw_call(_pair, b"", value=exact_value)
    
    # Slippage value
    # Return the extra amount
    if msg.value > input_value:
        slippage: uint256 = msg.value - input_value
        assert slippage > 0, "APEX:: UNVALID SLIPPAGE"
        raw_call(_nft_recipient, b"", value=slippage)

    log SwapETHForNFT(_pair, _nft_address, _nft_recipient, input_value, _token_ids)
    return True


@external
def swap_erc721_for_eth(
    _pair: address, 
    _nft_address: address,
    _eth_recipient: address, 
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE],
    _deadline: uint256
) -> bool:

    assert msg.sender != empty(address) and _eth_recipient != empty(address) and _pair != empty(address) and _nft_address != empty(address), "APEX:: UNVALIE ADDRESS"
    assert len(_token_ids) != 0, "APEX:: UNVALID ITEMS"
    assert ApexSwapV1Pair(_pair).pair_type() != 2, "APEX:: PAIR TRADE TYPE"
    self._check_deadline(_deadline)

    new_current_price: uint256 = 0
    output_value: uint256 = 0
    protocol_fee: uint256 = 0

    new_current_price, output_value, protocol_fee = self._swap_erc721_for_eth(_pair, _eth_recipient, _number_items, _token_ids)

    # transfer to recipient
    self._call_eth(_pair, _eth_recipient, output_value - protocol_fee, new_current_price)

    # transfer to fund
    self._call_eth(_pair, self.ape_fund, protocol_fee, new_current_price)

    log SwapNFTForETH(_pair, _nft_address, _eth_recipient, _token_ids)
    return True


@external
def swap_erc20_for_erc721(
    _pair: address,
    _nft_address: address,
    _token_address: address,
    _nft_recipient: address,
    _amount_in: uint256,
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE],
    _deadline: uint256
) -> bool:

    '''
    @dev Deflationary tokens are not supported
    '''
    assert _nft_address != empty(address) and _token_address != empty(address), "APEX:: UNVALIE ADDRESS"
    assert msg.sender != empty(address) and _pair != empty(address), "APEX:: UNVALIE ADDRESS"
    assert len(_token_ids) != 0, "APEX:: UNVALID ITEMS"

    self._check_deadline(_deadline)
    self._check_balance(_token_address, _nft_recipient, _amount_in)
    self._safe_transfer_erc20(_token_address, _nft_recipient, self, _amount_in)

    pay_value: uint256 = 0
    transfer_successful: bool = False

    transfer_successful, pay_value = self._swap_erc20_for_erc721(_pair, _nft_address, _token_address, _nft_recipient, _amount_in, _number_items, _token_ids)
    assert transfer_successful, "APEX:: UNVALID TRANSFER"

    if _amount_in > pay_value:
        slippage: uint256 = _amount_in - pay_value
        assert slippage > 0, "APEX:: UNVALID SLIPPAGE"
        self._safe_transfer_erc20(_token_address, self, _nft_recipient, slippage)

    log SwapERC20TokenForERC721(_pair, _nft_recipient, _number_items, _token_ids)

    return True


@external
def swap_erc721_for_erc20(
    _pair: address,
    _nft_address: address,
    _token_address: address,
    _token_recipient: address,
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE],
    _deadline: uint256
) -> bool:
    '''
    @dev Deflationary tokens are not supported
    '''
    assert _nft_address != empty(address) and _token_address != empty(address), "APEX:: UNVALIE ADDRESS"
    assert msg.sender != empty(address) and _pair != empty(address), "APEX:: UNVALIE ADDRESS"
    assert len(_token_ids) != 0, "APEX:: UNVALID ITEMS"
    self._check_deadline(_deadline)

    transfer_sucessful: bool = self._swap_erc721_for_erc20(_pair, _nft_address, _token_address, _token_recipient, _number_items, _token_ids)
    assert transfer_sucessful, "APEX:: UNVALID TRANSFER"

    log SwapERC721ForERC20Token(_pair, _token_recipient, _number_items, _token_ids)

    return True


@payable
@external
def addL_liquidity(
    _pair: address,
    _nft_address: address,
    _from: address,
    _to: address,
    _number_items: uint256, 
    _token_ids: DynArray[uint256, MAX_SIZE],
    _deadline: uint256
) -> bool:
    """
    @notice erc721 / eth
    """

    assert _nft_address != empty(address) and _from != empty(address) and _to != empty(address) and msg.sender != empty(address),"APEX:: UNVALID PAIR"
    assert ApexSwapV1Pair(_to).pair_type() == 0, "APEX:: PAIR TRADE TYPE"
    assert len(_token_ids) != 0 and len(_token_ids) == _number_items, "APEX:: UNVALID TOKEN ID"

    self._check_deadline(_deadline)
    self._check_ticket_owner(_pair, msg.sender)
    self._check_buy_value(_pair, _number_items, msg.value)

    raw_call(_to, b"", value=msg.value)

    for i in range(MAX_SIZE):
        if i >= _number_items:
            break
        else:
            self._safe_transfer_erc721(_pair, msg.sender, _to, _token_ids[i])
            log AddLiquidity(_to, _nft_address, _from, _number_items, _token_ids[i])

    return True


@external
def add_liquidity_en(
    _pair: address,
    _nft_address: address,
    _token_address: address,
    _from: address,
    _to: address,
    _number_items: uint256, 
    _amount_in: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE],
    _deadline: uint256
) -> bool:
    """
    @notice erc721 / erc20
    """

    assert _to != empty(address) and _nft_address != empty(address) and _token_address != empty(address) and _from != empty(address) and msg.sender != empty(address),"APEX:: UNVALID PAIR"
    assert ApexSwapV1Pair(_to).pair_type() == 0, "APEX:: PAIR TRADE TYPE"
    assert len(_token_ids) != 0 and len(_token_ids) == _number_items, "APEX:: UNVALID TOKEN ID"

    self._check_deadline(_deadline)
    self._check_ticket_owner(_pair, msg.sender)
    self._check_buy_value(_pair, _number_items, _amount_in)
    self._check_balance(_token_address, msg.sender, _amount_in)

    transfer_erc20_successful: bool = self._safe_transfer_erc20(_token_address, msg.sender, _to, _amount_in)
    assert transfer_erc20_successful, "APEX:: UNVALID TRANSFER FOR SEND"

    for i in range(MAX_SIZE):
        if i >= _number_items:
            break
        else:
            self._safe_transfer_erc721(_pair, msg.sender, _to, _token_ids[i])
            log AddLiquidityEN(_pair, _nft_address, _token_address, _from, _number_items, _token_ids[i])

    return True


@payable
@external
def add_liquidity_eth(
    _pair: address,
    _nft_address: address,
    _from: address,
    _to: address,
    _number_items: uint256,
    _deadline: uint256
) -> bool:

    assert _from != empty(address) and _to != empty(address) and msg.sender != empty(address),"APEX:: UNVALID PAIR"
    assert ApexSwapV1Pair(_to).pair_type() == 1, "APEX:: PAIR TRADE TYPE"
    assert _number_items != 0, "APEX:: EMPTY ITEM "

    self._check_deadline(_deadline)
    self._check_ticket_owner(_pair, msg.sender)
    self._check_buy_value(_pair, _number_items, msg.value)

    raw_call(_to, b"", value=msg.value)
    log AddLiquidityETH(_to, _nft_address, _from, _number_items)

    return True


@external
def add_liquidity_erc20(
    _pair: address,
    _token_address: address,
    _from: address, 
    _to: address,
    _number_items: uint256,
    _amount_in: uint256,
    _deadline: uint256
) -> bool:

    assert _from != empty(address) and _to != empty(address) and msg.sender != empty(address),"APEX:: UNVALID PAIR"
    assert _number_items != 0,"APEX:: UNVALID AMOUNT"

    self._check_deadline(_deadline)
    self._check_ticket_owner(_pair, msg.sender)
    self._check_buy_value(_pair, _number_items, _amount_in)
    self._check_balance(_token_address, msg.sender, _amount_in)

    transfer_erc20_successful: bool = self._safe_transfer_erc20(_token_address, msg.sender, _to, _amount_in)
    assert transfer_erc20_successful, "APEX:: UNVALID TRANSFER FOR SEND"

    log AddLiquidityERC20(_pair, _token_address, _from, _number_items)

    return True
    

@external
def add_liquidity_erc721(
    _pair: address,
    _nft_address: address,
    _from: address,
    _to: address,
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE],
    _deadline: uint256
) -> bool:

    assert _from != empty(address) and _to != empty(address) and msg.sender != empty(address) and _nft_address != empty(address),"APEX:: UNVALID ADDRESS"
    assert len(_token_ids) != 0 and len(_token_ids) == _number_items, "APEX:: UNVALID TOKEN ID"
    assert ApexSwapV1Pair(_to).pair_type() == 2, "APEX:: PAIR TRADE TYPE"
    
    self._check_deadline(_deadline)
    self._check_ticket_owner(_pair, msg.sender)

    for i in range(MAX_SIZE):
        if i >= len(_token_ids):
            break
        else:
            self._safe_transfer_erc721(_pair, msg.sender, _to, _token_ids[i])

            log AddLiquidityERC721NFT(_to, _nft_address, _from, _token_ids[i])

    return True


@external
def remove_liquidity(
    _pair: address, 
    _nft_address: address,
    _eth_recipient: address,
    _amount_in: uint256, 
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE],
    _deadline: uint256
) -> bool:

    assert _pair != empty(address),"APEX:: UNVALID PAIR"
    assert _amount_in != 0, "APEX:: UNVALID AMOUNT R"
    assert len(_token_ids) != 0, "APEX:: UNVALID TOKEN ID"

    self._check_deadline(_deadline)
    self._check_ticket_owner(_pair, msg.sender)
    self._check_sell_value(_pair, _number_items, _amount_in)

    cp: uint256 = ApexSwapV1Pair(_pair).current_price()
    
    self._call_eth(_pair, _eth_recipient, _amount_in, cp)

    for i in range(MAX_SIZE):
        if i >= len(_token_ids):
            break
        else:
            self._call_erc721(_pair, _nft_address, msg.sender, _token_ids[i], 0, cp)
            log RemoveLiquidity(_pair, _nft_address, _eth_recipient, _amount_in, _token_ids[i])

    return True


@external
def remove_liquidity_en(
    _pair: address, 
    _nft_address: address,
    _token_address: address,
    _token_recipient: address,
    _amount_in: uint256, 
    _token_ids: DynArray[uint256, MAX_SIZE],
    _deadline: uint256
) -> bool:

    assert _pair != empty(address) and _nft_address != empty(address) and _token_address != empty(address) and _token_recipient != empty(address) and msg.sender != empty(address),"APEX:: UNVALID PAIR"
    assert _amount_in != 0, "APEX:: UNVALID AMOUNT"
    assert len(_token_ids) != 0, "APEX:: UNVALID TOKEN ID"
    
    self._check_deadline(_deadline)
    self._check_ticket_owner(_pair, msg.sender)
    self._check_sell_value(_pair, len(_token_ids), _amount_in)

    cp: uint256 = ApexSwapV1Pair(_pair).current_price()

    self._call_erc20(_pair, _token_address, _token_recipient, _amount_in, 0, cp)

    for i in range(MAX_SIZE):
        if i >= len(_token_ids):
            break
        else:
            self._call_erc721(_pair, _nft_address, msg.sender, _token_ids[i], 0, cp)
            log RemoveLiquidityEN(_pair, _nft_address, _token_address, _token_recipient, _amount_in, _token_ids[i])

    return True


@external
def remove_liquidity_eth(
    _pair: address, 
    _eth_recipient: address,
    _number_items: uint256,
    _amount_in: uint256,
    _deadline: uint256
) -> bool:

    assert _pair != empty(address) and _eth_recipient != empty(address),"APEX:: UNVALID PAIR"
    assert _amount_in != 0, "APEX:: UNVALID AMOUNT"

    self._check_deadline(_deadline)
    self._check_ticket_owner(_pair, msg.sender)
    self._check_sell_value(_pair, _number_items, _amount_in)

    cp: uint256 = ApexSwapV1Pair(_pair).current_price()
    
    self._call_eth(_pair, _eth_recipient, _amount_in, cp)
    log RemoveLiquidityETH(_pair, _eth_recipient, _amount_in)

    return True


@external
def remove_liquidity_erc20(
    _pair: address, 
    _token_address: address,
    _token_recipient: address,
    _number_items: uint256,
    _amount_in: uint256,
    _deadline: uint256
) -> bool:

    assert _pair != empty(address) and _token_recipient != empty(address) and msg.sender != empty(address),"APEX:: UNVALID ADDRESS"
    assert _amount_in != 0, "APEX:: UNVALID AMOUNT"

    self._check_deadline(_deadline)
    self._check_ticket_owner(_pair, msg.sender)
    self._check_sell_value(_pair, _number_items, _amount_in)

    cp: uint256 = ApexSwapV1Pair(_pair).current_price()

    self._call_erc20(_pair, _token_address, _token_recipient, _amount_in, 0, cp)
    log RemoveLiquidityERC20(_pair, _token_recipient, _amount_in)

    return True


@external
def remove_liquidity_erc721(
    _pair: address, 
    _nft_address: address,
    _nft_recipient: address,
    _number_items: uint256,
    _token_ids: DynArray[uint256, MAX_SIZE],
    _deadline: uint256
) -> bool:

    assert _pair != empty(address) and _nft_address != empty(address) and msg.sender != empty(address) and _nft_recipient != empty(address),"APEX:: UNVALID ADDRESS"
    assert len(_token_ids) != 0 and len(_token_ids) == _number_items, "APEX:: UNVALID TOKEN ID"

    self._check_deadline(_deadline)
    self._check_ticket_owner(_pair, msg.sender)

    cp: uint256 = ApexSwapV1Pair(_pair).current_price()

    for i in range(MAX_SIZE):
        if i >= len(_token_ids):
            break
        else:
            self._call_erc721(_pair, _nft_address, msg.sender, _token_ids[i], 0, cp)
            log RemoveLiquidityERC721NFT(_pair, _nft_address, _nft_recipient, _token_ids[i])

    return True


@external
def set_ape_fee(_new_fee: uint256):
    assert msg.sender == self.owner, "APEX:: ONLY OWNER"

    old_fee: uint256 = self.ape_fee
    self.ape_fee = _new_fee
    log UpdateNewFee(msg.sender, old_fee, _new_fee)


@external
def set_factory(_new_factory: address):
    assert msg.sender == self.owner, "APEX:: ONLY OWNER"
    
    old_factory: address = self.factory
    self.factory = _new_factory
    log UpdateNewFactory(msg.sender, old_factory, _new_factory)


@external
def set_library(_new_library: address):
    assert msg.sender == self.owner, "APEX:: ONLY OWNER"

    old_library: address = self.library
    self.library = _new_library
    log UpdateNewLibrary(msg.sender, old_library, _new_library)


@external
def set_fund(_new_fund: address):
    assert msg.sender == self.owner, "APEX:: ONLY OWNER"

    old_fund: address = self.ape_fund
    self.ape_fund = _new_fund
    log UpdateNewFund(msg.sender, old_fund, _new_fund)

