import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { toast } from '@/components/ui/use-toast';
import { Loader2 } from 'lucide-react';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const { signIn, signUp } = useAuth();
  const navigate = useNavigate();
  const adminEmail = 'admin@sample.com';
  const adminPassword = 'test123password!';

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    const { error } = await signIn(email, password);

    if (error) {
      toast({ title: 'Error', description: error.message, variant: 'destructive' });
      setLoading(false);
    } else {
      toast({ title: 'Success', description: 'Logged in successfully!' });
      navigate('/');
    }
  };

  const handleCreateAdmin = async () => {
    setLoading(true);
    const { error: signUpError } = await signUp(adminEmail, adminPassword, { full_name: 'Admin' });

    if (signUpError && !/already registered/i.test(signUpError.message)) {
      toast({ title: 'Error', description: signUpError.message, variant: 'destructive' });
      setLoading(false);
      return;
    }

    const { error: signInError } = await signIn(adminEmail, adminPassword);
    if (signInError) {
      toast({ title: 'Error', description: signInError.message, variant: 'destructive' });
      setLoading(false);
      return;
    }

    toast({ title: 'Success', description: 'Admin user ready.' });
    navigate('/');
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100 p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle>Welcome Back</CardTitle>
          <CardDescription>Sign in to your SmartBooks24 account</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email">Email</Label>
              <Input id="email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password">Password</Label>
              <Input id="password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
            </div>
            <Button type="submit" className="w-full" disabled={loading}>
              {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Sign In
            </Button>
          </form>
          {import.meta.env.DEV && (
            <div className="mt-4 space-y-2">
              <Button
                type="button"
                variant="outline"
                className="w-full"
                onClick={() => {
                  setEmail(adminEmail);
                  setPassword(adminPassword);
                }}
              >
                Use admin login ({adminEmail})
              </Button>
              <Button
                type="button"
                variant="secondary"
                className="w-full"
                onClick={handleCreateAdmin}
                disabled={loading}
              >
                Create / sign in admin (dev)
              </Button>
              <p className="text-xs text-muted-foreground text-center">
                Dev-only helper. Ensure the user exists in Supabase Auth.
              </p>
            </div>
          )}
          <div className="mt-4 text-center text-sm space-y-2">
            <Link to="/reset-password" className="text-blue-600 hover:underline">Forgot password?</Link>
            <div>Don't have an account? <Link to="/signup" className="text-blue-600 hover:underline">Sign up</Link></div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
