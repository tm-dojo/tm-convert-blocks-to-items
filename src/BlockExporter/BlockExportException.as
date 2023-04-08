string BLOCK_EXCEPTION_PREFIX = "BLOCK_EXCEPTION:";

bool IsBlockException(string exceptionString) {
    return exceptionString.Contains(BLOCK_EXCEPTION_PREFIX);
}

string RemoveBlockExceptionPrefix(string exceptionString) {
    return exceptionString.Replace(BLOCK_EXCEPTION_PREFIX, "");
}

void ThrowBlockException(string message) {
    throw(BLOCK_EXCEPTION_PREFIX + message);
}