-- Support library: native-operators.
local NativeOperators = {}
function NativeOperators.sub(left, right)
	return left - right
end
function NativeOperators.add(left, right)
	return left + right
end
function NativeOperators.multiply(left, right)
	return left * right
end
function NativeOperators.dot(left, right)
	return left.x * right.x + left.y * right.y + left.z * right.z
end
function NativeOperators.length2D(vector)
	return math.sqrt(vector.x * vector.x + vector.y * vector.y)
end
function NativeOperators.length3D(vector)
	return math.sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
end
return NativeOperators
