# Additional mappings that are not present in the pygments lexers
# used for building stats
# format is {'ext':['Names']} eg. {'py':['Python']} note: there can be
# more than one name for extension
# NOTE: that this will overide any mappings in LANGUAGES_EXTENSIONS_MAP
# build by pygments
EXTRA_MAPPINGS = {}

# additional lexer definitions for custom files
# it's overrides pygments lexers, and uses defined name of lexer to colorize the
# files. Format is {'ext': 'lexer_name'}
# List of lexers can be printed running:
# python -c "import pprint;from pygments import lexers;pprint.pprint([(x[0], x[1]) for x in lexers.get_all_lexers()]);"

EXTRA_LEXERS = {}

#==============================================================================
# WHOOSH INDEX EXTENSIONS
#==============================================================================
# if INDEX_EXTENSIONS is [] it'll use pygments lexers extensions by default.
# To set your own just add to this list extensions to index with content
INDEX_EXTENSIONS = []

# additional extensions for indexing besides the default from pygments
# those gets added to INDEX_EXTENSIONS
EXTRA_INDEX_EXTENSIONS = []

#==============================================================================
# COMMON
#==============================================================================

import logging
import traceback
import re
log = logging.getLogger(__name__)

webhook_link_base = None
webhook_allow_list = ('^http://dummy\.placeholder\.example')

#==============================================================================
# POST CREATE REPOSITORY HOOK
#==============================================================================
# this function will be executed after each repository is created
def CREATE_REPO_HOOK(*args, **kwargs):
    """
    Post create repository HOOK
    kwargs available:
     :param repo_name:
     :param repo_type:
     :param description:
     :param private:
     :param created_on:
     :param enable_downloads:
     :param repo_id:
     :param owner_id:
     :param enable_statistics:
     :param clone_uri:
     :param fork_id:
     :param group_id:
     :param created_by:
    """


#==============================================================================
# PRE CREATE USER HOOK
#==============================================================================
# this function will be executed before each user is created
def PRE_CREATE_USER_HOOK(*args, **kwargs):
    """
    Pre create user HOOK, it returns a tuple of bool, reason.
    If bool is False the user creation will be stopped and reason
    will be displayed to the user.
    kwargs available:
    :param username:
    :param password:
    :param email:
    :param firstname:
    :param lastname:
    :param active:
    :param admin:
    :param created_by:
    """
    reason = 'allowed'
    return True, reason


#==============================================================================
# POST CREATE USER HOOK
#==============================================================================
# this function will be executed after each user is created
def CREATE_USER_HOOK(*args, **kwargs):
    """
    Post create user HOOK
    kwargs available:
      :param username:
      :param full_name_or_username:
      :param full_contact:
      :param user_id:
      :param name:
      :param firstname:
      :param short_contact:
      :param admin:
      :param lastname:
      :param ip_addresses:
      :param ldap_dn:
      :param email:
      :param api_key:
      :param last_login:
      :param full_name:
      :param active:
      :param password:
      :param emails:
      :param created_by:
    """


#==============================================================================
# POST CREATE PULLREQUEST HOOK
#==============================================================================
# this function will be executed after a pull request is created
def CREATE_PULLREQUEST_HOOK(*args, **kwargs):
    """
    Post create pull request HOOK
    kwargs available:
      :param pull_request_id:
      :param title:
      :param description:
      :param created_on:
      :param org_repo_id:
      :param org_ref:
      :param other_repo_id:
      :param other_ref:
      :param created_by:
    There are other fields in 'class PullRequest' (kallithea/model/db.py) which
    may or may not be useful for this hook.
    """


#==============================================================================
# POST DELETE REPOSITORY HOOK
#==============================================================================
# this function will be executed after each repository deletion
def DELETE_REPO_HOOK(*args, **kwargs):
    """
    Post delete repository HOOK
    kwargs available:
     :param repo_name:
     :param repo_type:
     :param description:
     :param private:
     :param created_on:
     :param enable_downloads:
     :param repo_id:
     :param owner_id:
     :param enable_statistics:
     :param clone_uri:
     :param fork_id:
     :param group_id:
     :param deleted_by:
     :param deleted_on:
    """


#==============================================================================
# POST DELETE USER HOOK
#==============================================================================
# this function will be executed after each user is deleted
def DELETE_USER_HOOK(*args, **kwargs):
    """
    Post delete user HOOK
    kwargs available:
      :param username:
      :param full_name_or_username:
      :param full_contact:
      :param user_id:
      :param name:
      :param firstname:
      :param short_contact:
      :param admin:
      :param lastname:
      :param ip_addresses:
      :param ldap_dn:
      :param email:
      :param api_key:
      :param last_login:
      :param full_name:
      :param active:
      :param password:
      :param emails:
      :param deleted_by:
    """


#==============================================================================
# POST PUSH HOOK
#==============================================================================

# this function will be executed after each push it's executed after the
# build-in hook that Kallithea uses for logging pushes
def PUSH_HOOK(*args, **kwargs):
    """
    Post push hook
    kwargs available:

      :param config: path to .ini config used
      :param scm: type of VS 'git' or 'hg'
      :param username: name of user who pushed
      :param ip: ip of who pushed
      :param action: push
      :param repository: repository name
      :param pushed_revs: list of pushed revisions
    """
    
    try:
        repo_name = kwargs['repository']
        user_name = kwargs['username']
        
        repo = get_repo_by_name(repo_name)
        if repo is None: return
        
        post_url = get_extra_field_url(repo, 'webhook-push-url')
        if post_url is None: return
        
        if webhook_allow_list:
            allow = any([re.match(pattern, post_url)  for pattern in webhook_allow_list])
            if not allow: return
        
        target_branches = get_extra_field_value(repo, 'webhook-push-branches')
        if target_branches:
            target_branches = target_branches.split()
            change_branches = get_change_branches(repo, kwargs['pushed_revs'])
            if (not change_branches) or (not set(target_branches).intersection(change_branches)): return
        
        if type(webhook_link_base) is str:
            link_base = webhook_link_base if webhook_link_base.endswith('/') else webhook_link_base + '/'
            msg = f'Pushed to [{repo_name}]({link_base}{repo_name}) by {user_name}'
        else:
            msg = f'Pushed to {repo_name} by {user_name}'
        
        msg_fmt = get_extra_field_value(repo, 'webhook-push-format')
        if msg_fmt is not None:
            fmt = msg_fmt.lower()
            if fmt == 'changes':
                changes = format_chengesets(repo, kwargs['pushed_revs'])
                if changes is not None:
                    msg += f"\n{changes}"
            elif fmt == 'revs':
                msg += f"\n  revs: {kwargs['pushed_revs']}"
        
        post_webhook(post_url, { 'text': msg, })
    except Exception:
        log.error(traceback.format_exc())


#==============================================================================
# POST PULL HOOK
#==============================================================================

# this function will be executed after each push it's executed after the
# build-in hook that Kallithea uses for logging pulls
def PULL_HOOK(*args, **kwargs):
    """
    Post pull hook
    kwargs available::

      :param config: path to .ini config used
      :param scm: type of VS 'git' or 'hg'
      :param username: name of user who pulled
      :param ip: ip of who pulled
      :param action: pull
      :param repository: repository name
    """


#==============================================================================
# UTILITIES
#==============================================================================

def get_repo_by_name(repo_name):
    from kallithea.model import db
    repo = db.Repository.guess_instance(repo_name)
    return repo

def get_extra_field_value(repo, key):
    for field in repo.extra_fields:
        if field.field_key == key:
            return field.field_value
    return None

def get_extra_field_url(repo, key):
    value = get_extra_field_value(repo, key)
    if value is None: return None
    if value.startswith('http://') or value.startswith('https://'):
        return value
    return None

def get_change_branches(repo, revs):
    if not isinstance(revs, list):
        return None
    
    for rev in revs:
        commit = repo.get_changeset(rev)
        if commit is None:
            continue
        
        branches = commit.branches
        if branches:
            return branches

    return None

def format_chengesets(repo, revs, max=5, indent='  '):
    if not isinstance(revs, list):
        return None
    
    changelist = ''
    count = 0;
    for rev in revs:
        count += 1
        if (max < count):
            changelist += f"{indent}(and more)\n"
            break
        commit = repo.get_changeset(rev)
        changelist += f"{indent}{commit.short_id}: {commit.message.splitlines()[0]}\n"
    return changelist

def post_webhook(url, data):
    import urllib.request
    import json
    postdata = json.dumps(data).encode()
    req = urllib.request.Request(url, postdata, method='POST', headers={ 'Content-Type': 'application/json', })
    with urllib.request.urlopen(req) as rsp:
        rsp.read()

