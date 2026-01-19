# L573 ANALYSIS REPORT - GET ENTRY SPECIFIC

**Date**: 2026-01-20
**Test**: L573 - GET /api/v1/cras/:cra_id/entries/:id
**Status**: ❌ FAILS - JSON:API Format Mismatch
**Priority**: P2 (Business Logic)
**Category**: GET / CRUD

---

## 🔍 TEST ANALYSIS

### Test Location
- **File**: `spec/requests/api/v1/cras/entries_spec.rb`
- **Line**: ~690-703
- **Test Name**: "returns the specific entry"
- **Context**: `describe 'GET /api/v1/cras/:cra_id/entries/:id'` → `context 'when entry exists'`

### Test Implementation
```ruby
it 'returns the specific entry' do
  get "/api/v1/cras/#{cra.id}/entries/#{cra_entry.id}", headers: headers

  expect(response).to have_http_status(:ok)

  json_response = JSON.parse(response.body)
  puts "DEBUG: json_response = #{json_response.inspect}"
  data = json_response['data']

  expect(data).to be_present
  expect(data['id']).to eq(cra_entry.id.to_s)
  expect(data['type']).to eq('cra_entry')
  expect(data['attributes']).to include('date', 'quantity', 'unit_price')
end
```

### Expected JSON:API Response Format
```json
{
  "data": {
    "id": "uuid",
    "type": "cra_entry",
    "attributes": {
      "date": "2025-01-15",
      "quantity": 1.0,
      "unit_price": 60000,
      "description": "Development work",
      "created_at": "2025-01-15T10:00:00Z",
      "updated_at": "2025-01-15T10:00:00Z"
    }
  }
}
```

---

## 🚨 PROBLEM IDENTIFIED

### Current Controller Response Format
**File**: `app/controllers/api/v1/cra_entries_controller.rb`
**Method**: `show` (lines 108-128)

```ruby
def show
  # Load and authorize CRA
  cra = Cra.find_by(id: params[:cra_id])
  return render json: { error: 'CRA not found', error_type: :not_found },
                status: http_status(:not_found) unless cra

  return unless authorize_cra!(cra)

  # Load entry with proper DDD relations
  entry = CraEntry.joins(:cra_entry_cras)
                  .where(cra_entry_cras: { cra_id: cra.id })
                  .find_by(id: params[:id])
  
  return render json: { error: 'Entry not found', error_type: :not_found },
                status: http_status(:not_found) unless entry

  # ❌ INCORRECT FORMAT - NOT JSON:API COMPLIANT
  entry_data = { entry: result_data_entry(entry) }
  cra_data = { cra: result_data_cra(cra) }

  render json: entry_data.merge(cra_data),
         status: http_status(:ok)
end

def result_data_entry(entry)
  {
    id: entry.id,
    date: entry.date,
    quantity: entry.quantity,
    unit_price: entry.unit_price,
    description: entry.description,
    created_at: entry.created_at,
    updated_at: entry.updated_at
  }
end

def result_data_cra(cra)
  {
    id: cra.id,
    total_days: cra.total_days,
    total_amount: cra.total_amount,
    currency: cra.currency,
    status: cra.status
  }
end
```

### Current Response Format
```json
{
  "entry": {
    "id": "uuid",
    "date": "2025-01-15",
    "quantity": 1.0,
    "unit_price": 60000,
    "description": "Development work",
    "created_at": "2025-01-15T10:00:00Z",
    "updated_at": "2025-01-15T10:00:00Z"
  },
  "cra": {
    "id": "uuid",
    "total_days": 1.0,
    "total_amount": 60000,
    "currency": "EUR",
    "status": "draft"
  }
}
```

### ❌ STRUCTURE MISMATCH

| Expected | Actual |
|----------|--------|
| `json_response['data']` | `json_response['entry']` + `json_response['cra']` |
| `data['type']` | ❌ Missing |
| `data['attributes']` | ❌ Flat structure |
| JSON:API compliant | ❌ Custom format |

---

## 🔧 ROOT CAUSE ANALYSIS

### 1. JSON:API Non-Compliance
- **Problem**: Controller uses custom format `{ entry: ..., cra: ... }`
- **Expected**: JSON:API format `{ data: { type, attributes } }`
- **Impact**: Test assertions fail on structure verification

### 2. Missing JSON:API Serialization
- **Problem**: No JSON:API serializer implemented
- **Current**: Direct hash merging in controller
- **Required**: JSON:API-compliant response structure

### 3. Over-fetching Data
- **Problem**: Controller returns both entry and CRA data
- **Expected**: Single resource (entry) with minimal CRA context
- **Impact**: Unnecessary data transfer, format complexity

---

## ✅ SOLUTION PROPOSED

### Option 1: JSON:API Serialization (Recommended)

**Step 1**: Create JSON:API serializer for CraEntry
```ruby
# app/serializers/cra_entry_serializer.rb
class CraEntrySerializer
  include FastJsonapi::ObjectSerializer
  
  attributes :date, :quantity, :unit_price, :description, :created_at, :updated_at
  
  belongs_to :cra, serializer: :CraSerializer
end
```

**Step 2**: Modify controller show method
```ruby
def show
  cra = Cra.find_by(id: params[:cra_id])
  return render json: { error: 'CRA not found', error_type: :not_found },
                status: http_status(:not_found) unless cra

  return unless authorize_cra!(cra)

  entry = CraEntry.joins(:cra_entry_cras)
                  .where(cra_entry_cras: { cra_id: cra.id })
                  .find_by(id: params[:id])
  
  return render json: { error: 'Entry not found', error_type: :not_found },
                status: http_status(:not_found) unless entry

  # ✅ JSON:API COMPLIANT RESPONSE
  render json: CraEntrySerializer.new(entry).serializable_hash,
         status: http_status(:ok)
end
```

### Option 2: Quick Fix (Minimal Change)

**Step 1**: Modify show method to return JSON:API format
```ruby
def show
  cra = Cra.find_by(id: params[:cra_id])
  return render json: { error: 'CRA not found', error_type: :not_found },
                status: http_status(:not_found) unless cra

  return unless authorize_cra!(cra)

  entry = CraEntry.joins(:cra_entry_cras)
                  .where(cra_entry_cras: { cra_id: cra.id })
                  .find_by(id: params[:id])
  
  return render json: { error: 'Entry not found', error_type: :not_found },
                status: http_status(:not_found) unless entry

  # ✅ JSON:API COMPLIANT RESPONSE
  render json: {
    data: {
      id: entry.id.to_s,
      type: 'cra_entry',
      attributes: {
        date: entry.date,
        quantity: entry.quantity,
        unit_price: entry.unit_price,
        description: entry.description,
        created_at: entry.created_at,
        updated_at: entry.updated_at
      }
    }
  }, status: http_status(:ok)
end
```

---

## 🧪 VALIDATION STEPS

### Test Execution Commands
```bash
# Run specific test
docker-compose run --rm web bundle exec rspec spec/requests/api/v1/cras/entries_spec.rb -e "returns the specific entry"

# Debug response
docker-compose run --rm web bundle exec rspec spec/requests/api/v1/cras/entries_spec.rb -e "returns the specific entry" --format documentation
```

### Expected Results After Fix
```ruby
# Test should pass with JSON:API format
{
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "type": "cra_entry",
    "attributes": {
      "date": "2025-01-15",
      "quantity": 1.0,
      "unit_price": 60000,
      "description": "Development work",
      "created_at": "2025-01-15T10:00:00Z",
      "updated_at": "2025-01-15T10:00:00Z"
    }
  }
}
```

### Validation Checklist
- [ ] Test L573 passes with HTTP 200
- [ ] JSON response contains `data` key
- [ ] `data['type']` equals 'cra_entry'
- [ ] `data['id']` matches entry ID
- [ ] `data['attributes']` contains required fields
- [ ] No regression on other CRUD operations
- [ ] Authorization still works correctly

---

## 📊 IMPACT ASSESSMENT

### Fix Complexity
- **Option 1 (Serializer)**: Medium - Requires gem and serialization layer
- **Option 2 (Quick Fix)**: Low - Direct JSON structure change

### Affected Areas
- **Controller**: `app/controllers/api/v1/cra_entries_controller.rb`
- **Tests**: `spec/requests/api/v1/cras/entries_spec.rb`
- **Response Format**: JSON:API compliance for L573 endpoint

### Risk Assessment
- **Low Risk**: Pure format change, no business logic modification
- **Dependency**: None on other features
- **Regression**: Minimal, only affects GET /:id endpoint

---

## 🚀 IMPLEMENTATION PLAN

### Phase 1: Quick Fix Implementation (Recommended)
1. **Modify controller show method** (30 minutes)
2. **Test L573 validation** (15 minutes)
3. **Verify other tests still pass** (30 minutes)

### Phase 2: JSON:API Serialization (Future)
1. **Install fast_jsonapi gem**
2. **Create serializers** for CraEntry and Cra
3. **Update controller** to use serializers
4. **Full test suite validation**

---

## ✅ RECOMMENDATION

**Immediate Action**: Implement Option 2 (Quick Fix)
- **Time**: < 1 hour
- **Risk**: Low
- **Impact**: L573 test passes, JSON:API format established
- **Future**: Can be enhanced with proper serialization later

**Pattern Established**: This fix will serve as template for other P2 tests (L585, L688, etc.) that need JSON:API compliance.

---

**Status**: ✅ Analysis Complete - Ready for Implementation
**Next Step**: Apply Option 2 fix to `app/controllers/api/v1/cra_entries_controller.rb`
