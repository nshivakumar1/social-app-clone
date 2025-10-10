# 🚀 Quick Start - Destroy Infrastructure

## Your Current Problem

You tried `terraform destroy` and got these errors:
- ❌ Subnet dependency violation
- ❌ Internet Gateway detachment failure
- ❌ "Network has mapped public addresses"

## ✅ Solution (Run This Now)

```bash
cd /Users/nakulshivakumar/Desktop/social-app-clone/infrastructure

# Check what resources exist
./verify-resources.sh

# Then run the automated safe destroy
./safe-destroy.sh
```

**That's it!** The script handles everything automatically.

---

## 📋 Alternative Options

### Option 1: Quick Manual Fix (3 minutes)
```bash
./force-cleanup-network.sh
terraform destroy
```

### Option 2: Layer-by-Layer (10 minutes, most thorough)
```bash
./targeted-destroy.sh
```

### Option 3: Check Resources First
```bash
./verify-resources.sh  # Shows what needs cleanup
```

---

## 🎯 What Each Script Does

| Script | Purpose | Time |
|--------|---------|------|
| **verify-resources.sh** | Shows current AWS resources | 30s |
| **force-cleanup-network.sh** | Fixes IGW/subnet errors | 2-3 min |
| **safe-destroy.sh** | Full automated destroy | 5-10 min |
| **targeted-destroy.sh** | Layer-by-layer destroy | 10-15 min |

---

## 📖 Full Documentation

For detailed info, see: [DESTROY_README.md](./DESTROY_README.md)

For summary, see: [DESTROY_SUMMARY.md](./DESTROY_SUMMARY.md)

---

## 🆘 If Scripts Fail

1. Check AWS credentials: `aws sts get-caller-identity`
2. Check region: `echo $AWS_REGION` (should be `us-east-1`)
3. Verify script permissions: `ls -la *.sh`
4. Read the error output carefully
5. Try `./verify-resources.sh` to see what's blocking

---

## ✨ What Was Fixed

### Terraform Improvements ✅
- Added lifecycle rules to prevent premature deletion
- Reduced ALB draining time (30s vs 300s)
- Disabled deletion protection on ALB
- Added proper dependency ordering
- Added ignore_changes for scaling configs

### New Helper Scripts ✅
- Pre-destroy cleanup automation
- Network resource force cleanup
- Resource verification
- Multiple destroy strategies

### Documentation ✅
- Complete destroy guide
- Troubleshooting steps
- Quick reference cards

---

## 💡 Remember

- **Always scale down first** (ECS/EKS services)
- **Wait for resources to drain** (30-60 seconds)
- **Don't skip cleanup steps**
- **Verify afterward** with `verify-resources.sh`

---

Ready? Start here:
```bash
cd infrastructure && ./safe-destroy.sh
```
