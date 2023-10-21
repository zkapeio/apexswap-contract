# @version 0.3.7

"""
@title ApexSwap Multi Call
@author zkape.io
"""

MAX_SIZE: constant(uint256) = 50

struct BatchValue:
    target: address
    allow_failure: bool
    value: uint256
    call_data: Bytes[10000]

struct Batch:
    target: address
    allow_failure: bool
    call_data: Bytes[10000]

struct Result:
    success: bool
    return_data: Bytes[255]


@external
def __init__():
    pass


@payable
@external
def __default__():
    pass


@payable
@external
def multi_call_value(_data: DynArray[BatchValue, MAX_SIZE]) -> DynArray[Result, MAX_SIZE]:
    assert len(_data) != 0, "APEX:: EMPTY DATA"

    pay_value: uint256 = 0
    results: DynArray[Result, MAX_SIZE] = []
    return_data: Bytes[32] = b""
    success: bool = False
    
    for batch in _data:
        pay_value += batch.value

        if batch.allow_failure == False:
            return_data = raw_call(batch.target, batch.call_data, max_outsize=32, value=batch.value)
            success = True
            results.append(Result({success: success, return_data: return_data}))
        else:
            success, return_data = \
                raw_call(batch.target, batch.call_data, max_outsize=32, value=batch.value, revert_on_failure=False)
            results.append(Result({success: success, return_data: return_data}))

    assert msg.value == pay_value, "APEX:: WRONG PAY"
    return results


@external
def multi_call(_data: DynArray[Batch, MAX_SIZE]) -> DynArray[Result, MAX_SIZE]:
    assert len(_data) != 0, "APEX:: EMPTY DATA"

    results: DynArray[Result, MAX_SIZE] = []
    return_data: Bytes[32] = b""
    success: bool = False
    
    for batch in _data:
        if batch.allow_failure == False:
            return_data = raw_call(batch.target, batch.call_data, max_outsize=32)
            success = True
            results.append(Result({success: success, return_data: return_data}))
        else:
            success, return_data = \
                raw_call(batch.target, batch.call_data, max_outsize=32, revert_on_failure=False)
            results.append(Result({success: success, return_data: return_data}))

    return results


@payable
@external
def multi_call_value_ms(
    _data: DynArray[BatchValue, MAX_SIZE], 
    _is_ms: bool, 
    _ms_data: BatchValue,
) -> DynArray[Result, MAX_SIZE]:

    pay_value: uint256 = 0
    results: DynArray[Result, MAX_SIZE] = []
    return_data: Bytes[32] = b""
    success: bool = False
    
    for batch in _data:
        pay_value += batch.value

        if batch.allow_failure == False:
            return_data = raw_call(batch.target, batch.call_data, max_outsize=32, value=batch.value)
            success = True
            results.append(Result({success: success, return_data: return_data}))
        else:
            success, return_data = \
                raw_call(batch.target, batch.call_data, max_outsize=32, value=batch.value, revert_on_failure=False)
            results.append(Result({success: success, return_data: return_data}))

    if _is_ms:
        pay_value += _ms_data.value
        return_data = raw_call(_ms_data.target, _ms_data.call_data, max_outsize=32, value=self.balance)
        success = True
        results.append(Result({success: success, return_data: return_data}))

    assert msg.value == pay_value, "APEX:: WRONG PAY"
    return results
